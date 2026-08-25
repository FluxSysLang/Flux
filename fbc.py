#!/usr/bin/env python3
"""
fbc.py -- Flux Borrow Checker

Copyright (C) 2026 Karac V. Thweatt

Performs a call-graph walk from the program entry point (FRTStartup by default)
and checks for pointer aliasing violations, scope escapes, and optionally
thread safety and heap leaks.

Usage:
    python fbc.py <file_or_dir> [options]

Options:
    --entry NAME      Entry point function name (default: FRTStartup)
    --warn            Treat violations as warnings instead of errors
    --threads         Also check thread safety (pointer escape across spawns)
    --leaks           Also check for heap leaks (unmatched fmalloc/ffree)
    --json            Machine-readable JSON output (for CI)
    --no-color        Disable ANSI color output

Exit codes:
    0   No violations (or --warn mode)
    1   One or more violations found (in default error mode)
"""

import sys
import os
import argparse
from pathlib import Path

# fbc modules
from fbc_alias import AliasMap, Violation
from fbc_report import print_violations, print_summary

# Flux compiler modules
# fbc.py lives at the project root alongside fxc.py.
# Compiler source is in src/compiler/ -- add that to the path.
_root = Path(__file__).parent
for _candidate in [
    _root / 'src' / 'compiler',
    _root / 'compiler',
    _root,
]:
    if (_candidate / 'fparser.py').exists():
        sys.path.insert(0, str(_candidate))
        break

try:
    from fparser import FluxParser
    from flexer import FluxLexer
    from fpreprocess import FXPreprocessor
    from fmacros import build_compiler_macros
    import fast
    from ftypesys import TypeSystem, Operator
except ImportError as e:
    print(f"[FBC] Error: could not import Flux compiler modules: {e}")
    print("      Looked for fparser.py in src/compiler/, compiler/, and project root.")
    sys.exit(2)

try:
    from fvm import FluxVM, VMError, Op, TTag, Instr, Val
    from fvmcodegen import FVMCodegen
    _FVM_AVAILABLE = True
except ImportError:
    _FVM_AVAILABLE = False

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _is_pointer_type(type_spec) -> bool:
    """Return True if a TypeSystem represents a pointer type."""
    if type_spec is None:
        return False
    return getattr(type_spec, 'is_pointer', False) or getattr(type_spec, 'pointer_depth', 0) > 0

def _node_file(node) -> str:
    return getattr(node, 'source_file', '<unknown>')

def _node_line(node) -> int:
    return getattr(node, 'source_line', 0)

def _make_stack_site(func_name: str, var_name: str, line: int) -> str:
    return f"stack:{func_name}:{var_name}@{line}"

def _make_heap_site(func_name: str, line: int) -> str:
    return f"heap:{func_name}:{line}"

def _make_param_site(func_name: str, param_name: str) -> str:
    return f"param:{func_name}:{param_name}"

def _is_fmalloc(node) -> bool:
    if isinstance(node, fast.FunctionCall):
        return node.name == 'fmalloc'
    return False

def _is_ffree(node) -> bool:
    if isinstance(node, fast.FunctionCall):
        return node.name == 'ffree'
    return False

def _is_thread_spawn(node) -> bool:
    """Heuristic: function calls that look like thread spawns."""
    if isinstance(node, fast.FunctionCall):
        return 'spawn' in node.name.lower() or 'thread' in node.name.lower()
    if isinstance(node, fast.MethodCall):
        name = getattr(node, 'name', '') or ''
        return 'spawn' in name.lower() or 'thread' in name.lower()
    return False

# ---------------------------------------------------------------------------
# Call graph builder
# ---------------------------------------------------------------------------

class CallGraph:
    """Collects all FunctionDef nodes keyed by name for call resolution."""

    def __init__(self):
        # name -> FunctionDef
        self.funcs: dict[str, fast.FunctionDef] = {}
        # short name -> mangled name, for intra-namespace call resolution
        self.short_names: dict[str, str] = {}
        # base name -> list of mangled names (for overload resolution at call sites)
        self.overloads: dict[str, list] = {}
        # func_name -> set of call-context tuples already analysed (main context)
        self.visited_main: dict[str, set[tuple]] = {}
        # func_name -> set of call-context tuples already analysed (thread context)
        self.visited_thread: dict[str, set[tuple]] = {}
        # how many times each function has been passed to a thread spawn
        # name -> int
        self.spawn_count: dict[str, int] = {}

    # kept as a property so existing code that reads cg.visited still compiles
    # returns the set of function names that have been analysed in at least one context
    @property
    def visited(self) -> set[str]:
        return set(self.visited_main.keys())

    def is_visited(self, name: str, ctx: tuple, thread: bool) -> bool:
        """Return True if this (name, ctx) pair has already been analysed."""
        table = self.visited_thread if thread else self.visited_main
        return ctx in table.get(name, set())

    def mark_visited(self, name: str, ctx: tuple, thread: bool):
        """Record that (name, ctx) has been analysed."""
        table = self.visited_thread if thread else self.visited_main
        table.setdefault(name, set()).add(ctx)

    def collect(self, program: fast.Program):
        """Walk the top-level program and collect all function definitions."""
        for node in program.statements:
            self._collect_node(node)
        # build short name index and overload index
        short_count: dict[str, int] = {}
        for mangled in self.funcs:
            short = mangled.split('__')[-1]
            short_count[short] = short_count.get(short, 0) + 1
        for mangled in self.funcs:
            short = mangled.split('__')[-1]
            if short_count[short] == 1:
                self.short_names[short] = mangled
            # overload index: base name is everything before the __N__ arity segment
            # split on __ and find the first all-digit segment; base is parts before it
            # e.g. main__0__ret_intE1 -> parts=['main','0','ret_intE1'] -> base='main'
            parts = mangled.split('__')
            base = mangled
            for idx, part in enumerate(parts):
                if part.isdigit():
                    base = '__'.join(parts[:idx])
                    break
            self.overloads.setdefault(base, []).append(mangled)

    def _collect_node(self, node, ns_prefix: str = ''):
        if isinstance(node, fast.FunctionDef):
            if not node.is_prototype:
                self.funcs[node.name] = node
        elif isinstance(node, fast.FunctionDefStatement):
            self._collect_node(node.function_def, ns_prefix)
        elif isinstance(node, fast.NamespaceDefStatement):
            self._collect_node(node.namespace_def, ns_prefix)
        elif isinstance(node, fast.NamespaceDef):
            prefix = f"{ns_prefix}__{node.name}" if ns_prefix else node.name
            for func in node.functions:
                if not func.is_prototype:
                    mangled = f"{prefix}__{func.name}"
                    self.funcs[mangled] = func
            for obj in node.objects:
                self._collect_object(obj, prefix=prefix)
            for ns in node.nested_namespaces:
                self._collect_node(ns, ns_prefix=prefix)
        elif isinstance(node, fast.ObjectDef):
            self._collect_object(node, prefix=ns_prefix)
        elif isinstance(node, fast.ObjectDefStatement):
            self._collect_object(node.object_def, prefix=ns_prefix)
        elif isinstance(node, fast.StructDef):
            pass
        elif isinstance(node, fast.StructDefStatement):
            pass
        elif isinstance(node, fast.ExternBlock):
            pass
        elif isinstance(node, fast.ExportBlock):
            for func in node.definitions:
                if not func.is_prototype:
                    self.funcs[func.name] = func

    def _collect_object(self, obj, prefix: str):
        # guard: only ObjectDef has methods we can walk; TraitDef/InterfaceDef do not
        if not isinstance(obj, fast.ObjectDef):
            return
        for method in obj.methods:
            if method.name and method.body:
                mangled = f"{prefix}__{obj.name}__{method.name}" if prefix else f"{obj.name}__{method.name}"
                self.funcs[mangled] = method
        for nested in obj.nested_objects:
            self._collect_object(nested, prefix=f"{prefix}__{obj.name}" if prefix else obj.name)

# ---------------------------------------------------------------------------
# AST Walker
# ---------------------------------------------------------------------------

class _SyntheticCall:
    """Minimal stand-in for a FunctionCall node used when resolving MethodCall targets."""
    def __init__(self, name, arguments, source_file, source_line):
        self.name = name
        self.arguments = arguments
        self.source_file = source_file
        self.source_line = source_line


class BorrowChecker:

    def __init__(self, call_graph: CallGraph, entry: str,
                 check_threads: bool = False,
                 check_leaks: bool = False,
                 line_map: list = None):
        self.cg = call_graph
        self.entry = entry
        self.check_threads = check_threads
        self.check_leaks = check_leaks
        self.line_map = line_map or []
        self.alias = AliasMap()
        self.violations: list[Violation] = []
        self.funcs_checked = 0
        # True while walking a function that was invoked from a thread spawn
        self._in_thread_context: bool = False
        # set of function names currently on the active call stack -- prevents
        # infinite recursion when context-sensitive re-entry produces a new
        # call_ctx tuple for an already-active recursive function
        self._call_stack: set[str] = set()
        self._current_func_node: fast.FunctionDef | None = None
        # cache for FVM expression evaluation -- keyed by id(ast_node)
        # stores the result (int, str, or None) so each node is only executed once
        self._fvm_cache: dict[int, object] = {}
        # tracks which heap sites have been stored into arrays:
        # array variable name -> set of heap site strings
        # used to resolve ffree(arr[i]) back to the original heap site
        self._array_heap_sites: dict[str, set] = {}

    def _remap(self, merged_line: int) -> tuple:
        """Map a merged-source line number back to (original_file, original_line)."""
        idx = merged_line - 1
        if self.line_map and 0 <= idx < len(self.line_map):
            fname, orig_line = self.line_map[idx]
            return fname, orig_line
        return '<unknown>', merged_line

    def run(self):
        """Start walk from entry point."""
        if self.entry not in self.cg.funcs:
            print(f"[FBC] Warning: entry point '{self.entry}' not found as a non-prototype function.")
            print(f"      This usually means the entry point body is inside an unresolved #ifdef block.")
            print(f"      Checking all reachable functions instead.")
            for name, func in self.cg.funcs.items():
                if not self.cg.is_visited(name, (), False):
                    self._check_function(func)
        else:
            self._check_function(self.cg.funcs[self.entry])

    # Functions whose job is to allocate and return -- fmalloc inside them
    # that reaches a return statement transfers ownership to the caller, not a leak.
    _ALLOCATOR_FUNCS = {
        'fmalloc', 'ffree',
    }

    def _func_returns_allocation(self, func) -> bool:
        """True if this function is a known allocator wrapper -- fmalloc result returned directly."""
        if func.name in self._ALLOCATOR_FUNCS:
            return True
        if not func.body:
            return False
        # heuristic: single-statement body that returns an fmalloc call or calls fmalloc
        stmts = func.body.statements
        if len(stmts) == 1:
            s = stmts[0]
            if isinstance(s, fast.ReturnStatement) and s.value:
                if _is_fmalloc(s.value):
                    return True
                if isinstance(s.value, fast.CastExpression) and _is_fmalloc(s.value.expression):
                    return True
                if isinstance(s.value, fast.FunctionCall) and isinstance(s.value.name, str):
                    if 'malloc' in s.value.name.lower() or 'alloc' in s.value.name.lower():
                        return True
            if isinstance(s, fast.ExpressionStatement):
                expr = s.expression
                if isinstance(expr, fast.ReturnStatement) and expr.value:
                    if _is_fmalloc(expr.value):
                        return True
        return False

    def _check_function(self, func: fast.FunctionDef, thread_context: bool = False,
                        call_ctx: tuple = ()):
        """
        Analyse one function body.

        call_ctx is a tuple of site strings, one per pointer parameter in
        declaration order, derived from the actual argument expressions at the
        call site.  When a positional site is available it replaces the opaque
        param:<func>:<name> site so alias checking operates on real identities
        across the call boundary.  An empty tuple means the caller could not
        resolve any argument sites (e.g. the call target was not in the call
        graph) and the opaque fallback is used for every parameter.
        """
        if self.cg.is_visited(func.name, call_ctx, thread_context):
            return
        # guard against re-entrant recursion: a recursive function called with a
        # new call_ctx would pass the visited check but is already active on the
        # call stack -- analysing it again would loop forever
        if func.name in self._call_stack:
            return
        self.cg.mark_visited(func.name, call_ctx, thread_context)
        self._call_stack.add(func.name)
        self.funcs_checked += 1

        prev_func = self.alias.func_name
        prev_thread_ctx = self._in_thread_context
        prev_func_node = self._current_func_node
        # isolate callee from caller's live pointer frames so that
        # _check_mutable_alias only sees pointers declared inside this
        # function, not the caller's scope chain
        prev_frames = self.alias.frames
        self.alias.frames = []
        prev_heap_sites = dict(self.alias.heap_sites)
        self.alias.heap_sites = {}
        prev_freed_sites = dict(self.alias.freed_sites)
        self.alias.freed_sites = {}
        prev_alloc_sizes = dict(self.alias.alloc_sizes)
        self.alias.alloc_sizes = {}
        prev_array_heap_sites = self._array_heap_sites
        self._array_heap_sites = {}
        self.alias.func_name = func.name
        self._in_thread_context = thread_context
        self._current_func_node = func

        self.alias.push_scope()

        # register pointer parameters
        # if a positional site was supplied by the caller, use it; otherwise
        # fall back to the opaque param: site
        ptr_params = [p for p in (func.parameters or []) if p.name and _is_pointer_type(p.type_spec)]
        param_sites = []
        for idx, param in enumerate(ptr_params):
            if idx < len(call_ctx) and call_ctx[idx] not in ('unknown', ''):
                site = call_ctx[idx]
                # propagate the caller's known allocation size for this site
                # so bounds checks inside the callee have the size available
                if site in prev_alloc_sizes:
                    self.alias.alloc_sizes[site] = prev_alloc_sizes[site]
            else:
                site = _make_param_site(func.name, param.name)
            self.alias.declare_ptr(
                var_name=param.name,
                site=site,
                mutable=True,  # conservative: treat all pointer params as mutable
                file=_node_file(func),
                line=_node_line(func),
            )
            param_sites.append((param.name, site))
        # check parameter pairs for aliasing -- this is the interprocedural catch:
        # two parameters with the same caller-propagated site are mutable aliases
        self.alias.check_call_args(param_sites, _node_file(func), _node_line(func))

        if func.body:
            self._walk_block(func.body)

        if self.check_leaks and not self._func_returns_allocation(func):
            self.alias.check_heap_leaks()
        else:
            self.alias.heap_sites.clear()
            self.alias.freed_sites.clear()
            self.alias.alloc_sizes.clear()

        self.alias.pop_scope()
        self._call_stack.discard(func.name)
        # restore caller's frame state
        self.alias.frames = prev_frames
        self.alias.heap_sites = prev_heap_sites
        self.alias.freed_sites = prev_freed_sites
        self.alias.alloc_sizes = prev_alloc_sizes
        self._array_heap_sites = prev_array_heap_sites
        self.alias.func_name = prev_func
        self._current_func_node = prev_func_node
        self._in_thread_context = prev_thread_ctx

        # collect violations -- remap merged line numbers to original source locations
        for v in self.alias.violations:
            fname, orig_line = self._remap(v.line)
            v.file = fname
            v.line = orig_line
            # remap detail lines that contain "at <unknown>:N" patterns
            remapped_detail = []
            for d in v.detail:
                parts = d.split(' at ')
                if len(parts) == 2:
                    loc = parts[1]
                    colon = loc.rfind(':')
                    if colon != -1:
                        try:
                            merged = int(loc[colon+1:])
                            df, dl = self._remap(merged)
                            d = parts[0] + f' at {df}:{dl}'
                        except ValueError:
                            pass
                remapped_detail.append(d)
            v.detail = remapped_detail
        seen = {self._violation_key(v) for v in self.violations}
        for v in self.alias.violations:
            if self._violation_key(v) not in seen:
                self.violations.append(v)
                seen.add(self._violation_key(v))
        self.alias.violations.clear()

    def _violation_key(self, v) -> tuple:
        return (v.kind, v.file, v.line, v.message)

    def _walk_block(self, block: fast.Block):
        self.alias.push_scope()
        for stmt in block.statements:
            if stmt is not None:
                self._walk_stmt(stmt)
        self.alias.pop_scope(check_leaks=self.check_leaks)

    def _walk_stmt(self, node):
        file = _node_file(node)
        line = _node_line(node)

        if isinstance(node, fast.VariableDeclaration):
            self._on_var_decl(node)

        elif isinstance(node, fast.Assignment):
            self._on_assign(node)

        elif isinstance(node, fast.CompoundAssignment):
            self._walk_expr(node.value)

        elif isinstance(node, fast.ExpressionStatement):
            self._walk_expr(node.expression)

        elif isinstance(node, fast.Block):
            self._walk_block(node)

        elif isinstance(node, fast.IfStatement):
            self._walk_expr(node.condition)
            # snapshot freed_sites and heap_sites before each branch
            pre_freed = dict(self.alias.freed_sites)
            pre_heap  = dict(self.alias.heap_sites)
            if node.then_block:
                self._walk_block(node.then_block)
            then_freed = dict(self.alias.freed_sites)
            then_heap  = dict(self.alias.heap_sites)
            # restore to pre-branch state before walking else
            self.alias.freed_sites = dict(pre_freed)
            self.alias.heap_sites  = dict(pre_heap)
            if node.else_block:
                self._walk_block(node.else_block)
            else_freed = dict(self.alias.freed_sites)
            else_heap  = dict(self.alias.heap_sites)
            # freed_sites intersection: only keep sites freed on ALL paths
            if node.else_block:
                self.alias.freed_sites = {s: v for s, v in then_freed.items() if s in else_freed}
                # heap_sites union: keep sites that might not be freed on all paths
                merged_heap = dict(then_heap)
                merged_heap.update(else_heap)
                # only drop a site if it was freed on both paths (not in either heap snapshot)
                self.alias.heap_sites = {s: v for s, v in merged_heap.items()
                                         if s in then_heap or s in else_heap}
            else:
                self.alias.freed_sites = dict(pre_freed)
                # no else -- then-branch allocs may or may not have been freed
                merged_heap = dict(pre_heap)
                merged_heap.update(then_heap)
                self.alias.heap_sites = merged_heap

        elif isinstance(node, fast.WhileLoop):
            self._walk_expr(node.condition)
            if node.body:
                pre_freed = dict(self.alias.freed_sites)
                pre_heap  = dict(self.alias.heap_sites)
                self._walk_block(node.body)
                # restore freed_sites -- loop may not execute (UAF tracking)
                self.alias.freed_sites = dict(pre_freed)
                # loop_heap is the post-walk state: sites freed inside the loop
                # body have already been removed from heap_sites by record_free.
                # Merge: keep post-walk state (respects in-loop frees) but also
                # retain any pre-existing sites that were not touched by the loop.
                loop_heap = dict(self.alias.heap_sites)
                # Sites in pre_heap that are also absent from loop_heap were freed
                # inside the loop body -- keep them absent (freed).
                # Sites in loop_heap that were not in pre_heap are new allocations
                # from inside the loop body -- keep them present (may leak).
                merged_heap = {s: v for s, v in pre_heap.items() if s in loop_heap}
                merged_heap.update({s: v for s, v in loop_heap.items() if s not in pre_heap})
                self.alias.heap_sites = merged_heap

        elif isinstance(node, fast.DoWhileLoop):
            if node.body:
                pre_freed = dict(self.alias.freed_sites)
                pre_heap  = dict(self.alias.heap_sites)
                self._walk_block(node.body)
                self.alias.freed_sites = dict(pre_freed)
                loop_heap = dict(self.alias.heap_sites)
                merged_heap = {s: v for s, v in pre_heap.items() if s in loop_heap}
                merged_heap.update({s: v for s, v in loop_heap.items() if s not in pre_heap})
                self.alias.heap_sites = merged_heap
            self._walk_expr(node.condition)

        elif isinstance(node, fast.ForLoop):
            if node.init:
                self._walk_stmt(node.init)
            if node.condition:
                self._walk_expr(node.condition)
            if node.update:
                self._walk_stmt(node.update)
            if node.body:
                pre_freed = dict(self.alias.freed_sites)
                pre_heap  = dict(self.alias.heap_sites)
                self._walk_block(node.body)
                self.alias.freed_sites = dict(pre_freed)
                loop_heap = dict(self.alias.heap_sites)
                merged_heap = {s: v for s, v in pre_heap.items() if s in loop_heap}
                merged_heap.update({s: v for s, v in loop_heap.items() if s not in pre_heap})
                self.alias.heap_sites = merged_heap

        elif isinstance(node, fast.ForInLoop):
            if node.body:
                pre_freed = dict(self.alias.freed_sites)
                pre_heap  = dict(self.alias.heap_sites)
                self._walk_block(node.body)
                self.alias.freed_sites = dict(pre_freed)
                loop_heap = dict(self.alias.heap_sites)
                merged_heap = {s: v for s, v in pre_heap.items() if s in loop_heap}
                merged_heap.update({s: v for s, v in loop_heap.items() if s not in pre_heap})
                self.alias.heap_sites = merged_heap

        elif isinstance(node, fast.SwitchStatement):
            self._walk_expr(node.expression)
            pre_freed = dict(self.alias.freed_sites)
            pre_heap  = dict(self.alias.heap_sites)
            case_freeds = []
            case_heaps  = []
            for case in node.cases:
                self.alias.freed_sites = dict(pre_freed)
                self.alias.heap_sites  = dict(pre_heap)
                if case.body:
                    self._walk_block(case.body)
                case_freeds.append(dict(self.alias.freed_sites))
                case_heaps.append(dict(self.alias.heap_sites))
            if case_freeds:
                intersection = dict(case_freeds[0])
                for cf in case_freeds[1:]:
                    intersection = {s: v for s, v in intersection.items() if s in cf}
                self.alias.freed_sites = intersection
                merged_heap = {}
                for ch in case_heaps:
                    merged_heap.update(ch)
                self.alias.heap_sites = merged_heap
            else:
                self.alias.freed_sites = dict(pre_freed)
                self.alias.heap_sites  = dict(pre_heap)

        elif isinstance(node, fast.ReturnStatement):
            if node.value:
                self._walk_expr(node.value)

        elif isinstance(node, fast.DeferStatement):
            # deferred code executes at function exit, not at this point in
            # control flow -- snapshot freed_sites so any ffree inside the
            # defer body does not falsely mark sites as freed for UAF purposes.
            # heap_sites is NOT snapshotted -- a deferred ffree genuinely removes
            # the site from leak tracking, same as an immediate ffree would.
            pre_freed = dict(self.alias.freed_sites)
            if node.expression:
                self._walk_expr(node.expression)
            if node.body:
                for s in node.body:
                    self._walk_stmt(s)
            self.alias.freed_sites = dict(pre_freed)

        elif isinstance(node, fast.TryBlock):
            if node.try_body:
                pre_freed = dict(self.alias.freed_sites)
                pre_heap  = dict(self.alias.heap_sites)
                self._walk_block(node.try_body)
                try_freed = dict(self.alias.freed_sites)
                try_heap  = dict(self.alias.heap_sites)
            else:
                pre_freed = dict(self.alias.freed_sites)
                pre_heap  = dict(self.alias.heap_sites)
                try_freed = dict(pre_freed)
                try_heap  = dict(pre_heap)
            catch_freeds = []
            catch_heaps  = []
            for _, _, catch_body in (node.catch_blocks or []):
                self.alias.freed_sites = dict(pre_freed)
                self.alias.heap_sites  = dict(pre_heap)
                self._walk_block(catch_body)
                catch_freeds.append(dict(self.alias.freed_sites))
                catch_heaps.append(dict(self.alias.heap_sites))
            # intersection of try and all catch paths for freed_sites
            all_paths = [try_freed] + catch_freeds
            intersection = dict(all_paths[0])
            for pf in all_paths[1:]:
                intersection = {s: v for s, v in intersection.items() if s in pf}
            self.alias.freed_sites = intersection
            # union of heap_sites across all paths
            all_heaps = [try_heap] + catch_heaps
            merged_heap = {}
            for h in all_heaps:
                merged_heap.update(h)
            self.alias.heap_sites = merged_heap

        elif isinstance(node, fast.FunctionDefStatement):
            # nested function def -- walk it under current context
            self._check_function(node.function_def, thread_context=self._in_thread_context)

        # other statement types (break, continue, label, goto, assert etc.)
        # don't introduce pointers so we skip them

    @staticmethod
    def _rhs_is_heap_alloc(expr) -> bool:
        """Return True if expr is fmalloc() or a cast/type-convert wrapping fmalloc()."""
        if expr is None:
            return False
        if _is_fmalloc(expr):
            return True
        if isinstance(expr, (fast.CastExpression, fast.TypeConvertExpression)):
            return BorrowChecker._rhs_is_heap_alloc(expr.expression)
        return False

    def _on_var_decl(self, node: fast.VariableDeclaration):
        file = _node_file(node)
        line = _node_line(node)
        is_ptr = _is_pointer_type(node.type_spec)

        # A variable that stores an fmalloc result must be tracked as a heap
        # pointer regardless of its declared type (e.g. long addr = fmalloc(n)).
        # Without this, ffree(addr) cannot resolve the site and the allocation
        # appears to leak.
        if not is_ptr and self.check_leaks and self._rhs_is_heap_alloc(node.initial_value):
            is_ptr = True

        # Always register the stack site for this variable so its address
        # can be tracked if taken later
        site = _make_stack_site(self.alias.func_name, node.name, line)

        if is_ptr:
            # it's a pointer variable -- what does it point to?
            ptr_site = self._resolve_site(node.initial_value, node.name, file, line)
            # if the RHS is a plain identifier, exclude it from the alias check
            # so that a pointer copy (byte* q = p) does not self-report as an alias --
            # q IS p, they're the same pointer, not a genuine alias.
            # pointer arithmetic (byte* q = p + 8) is a different view into the same
            # allocation -- that IS a genuine alias and must not be excluded.
            rhs = node.initial_value
            if isinstance(rhs, fast.Identifier):
                source_var = rhs.name
            elif isinstance(rhs, (fast.CastExpression, fast.TypeConvertExpression)):
                inner = rhs.expression
                if isinstance(inner, fast.Identifier):
                    source_var = inner.name
                else:
                    source_var = None
            else:
                source_var = None
            #import sys as _sys; _sys.stderr.write(f'[FBC DEBUG] declare_ptr: name={node.name!r} site={ptr_site!r} func={self.alias.func_name!r}\n'); _sys.stderr.flush()
            self.alias.declare_ptr(
                var_name=node.name,
                site=ptr_site,
                mutable=True,
                file=file,
                line=line,
                is_stack_owner=False,
                source_var=source_var,
            )
        else:
            # non-pointer stack variable -- register its site so @node.name can be resolved
            if self.alias.frames:
                frame = self.alias.frames[-1]
                frame.owned_sites.add(site)
                frame.var_sites[node.name] = site
            # if this is a fixed-size stack array, record the element count as
            # the allocation size so bounds checks can use it
            ts = node.type_spec
            if ts is not None and getattr(ts, 'array_size', None) is not None:
                arr_sz = ts.array_size
                if isinstance(arr_sz, int):
                    self.alias.record_alloc_size(site, arr_sz)
                elif hasattr(arr_sz, 'value') and isinstance(arr_sz.value, int):
                    self.alias.record_alloc_size(site, int(arr_sz.value))
                else:
                    # non-constant array size -- try FVM evaluation
                    evaled = self._eval_size_via_fvm(arr_sz)
                    if evaled is not None:
                        self.alias.record_alloc_size(site, evaled)

        if node.initial_value:
            self._walk_expr(node.initial_value)

    def _on_assign(self, node: fast.Assignment):
        file = _node_file(node)
        line = _node_line(node)
        self._walk_expr(node.value)

        # is the target a pointer variable?
        if isinstance(node.target, fast.Identifier):
            var_name = node.target.name
            # check if we know this var as a pointer
            existing = self.alias._find_ptr(var_name)
            if existing is not None:
                new_site = self._resolve_site(node.value, var_name, file, line)
                source_var = node.value.name if isinstance(node.value, fast.Identifier) else None
                self.alias.assign_ptr(var_name, new_site, True, file, line, source_var=source_var)
            elif self.check_leaks and self._rhs_is_heap_alloc(node.value):
                # non-pointer-typed variable being assigned an fmalloc result --
                # register it so ffree(var) can resolve the site later
                new_site = self._resolve_site(node.value, var_name, file, line)
                self.alias.declare_ptr(
                    var_name=var_name,
                    site=new_site,
                    mutable=True,
                    file=file,
                    line=line,
                    is_stack_owner=False,
                    source_var=None,
                )

        # arr[i] = ptr -- record that arr contains heap sites so ffree(arr[j])
        # can be resolved back to a valid heap site
        if self.check_leaks and isinstance(node.target, fast.ArrayAccess):
            base = node.target.array
            if isinstance(base, fast.Identifier):
                arr_name = base.name
                rhs_site = None
                if isinstance(node.value, fast.Identifier):
                    info = self.alias._find_ptr(node.value.name)
                    if info and info.site in self.alias.heap_sites:
                        rhs_site = info.site
                if rhs_site:
                    if arr_name not in self._array_heap_sites:
                        self._array_heap_sites[arr_name] = set()
                    self._array_heap_sites[arr_name].add(rhs_site)

    _SPAWN_IMPL_FUNCS = {'thread_create', 'thread_create_stack', 'pthread_create', 'CreateThread'}

    def _in_spawn_impl(self) -> bool:
        return any(impl in self.alias.func_name for impl in self._SPAWN_IMPL_FUNCS)

    def _check_ident_escape(self, name: str, file: str, line: int):
        """Check if using this identifier touches a thread-escaped site."""
        if self.check_threads and not self._in_spawn_impl():
            self.alias.check_use_after_escape(name, file, line)

    def _unwrap_ptr_ident(self, expr) -> str:
        """Unwrap casts/address-of to find the underlying pointer variable name, if any."""
        if isinstance(expr, fast.Identifier):
            return expr.name
        if isinstance(expr, (fast.CastExpression, fast.TypeConvertExpression)):
            return self._unwrap_ptr_ident(expr.expression)
        if isinstance(expr, fast.AddressOf):
            return self._unwrap_ptr_ident(expr.expression)
        if isinstance(expr, fast.FunctionCall) and expr.arguments:
            return self._unwrap_ptr_ident(expr.arguments[0])
        return None

    def _resolve_fptr_expr(self, expr) -> str | None:
        """
        Compile and execute an arbitrary expression through the FVM to resolve
        a function pointer value to a callee name.

        The FVM represents function pointers as Val(TTag.BYTES, func_name_bytes).
        Executing the expression leaves that value on the stack; we decode it
        and look it up in the call graph.

        Returns the resolved mangled function name, or None if the expression
        cannot be executed or does not resolve to a known function.
        """
        if not _FVM_AVAILABLE:
            return None
        try:
            cg = FVMCodegen()
            cg._visit_expr(expr)
            cg._emit(Instr(Op.HALT, [], 0))
            vm = FluxVM()
            for name, instrs in cg.compiled_functions.items():
                vm.register_function(name, instrs)
            vm.execute(cg._instructions, cg._local_count)
            if not vm.stack:
                return None
            top = vm.stack[-1]
            if top.tag == TTag.BYTES:
                name = top.data.decode('utf-8') if isinstance(top.data, (bytes, bytearray)) else str(top.data)
            elif top.tag == TTag.PTR:
                # PTR may carry a meta dict with a function name when used as a func ptr slot
                meta = getattr(top, 'meta', {}) or {}
                name = meta.get('func_name') or str(top.data)
            else:
                return None
            name = name.strip()
            if name in self.cg.funcs:
                return name
            if name in self.cg.short_names:
                return self.cg.short_names[name]
            return None
        except Exception:
            return None

    def _collect_arg_sites(self, args: list, file: str, line: int) -> list:
        """
        Resolve each argument expression to a (name_hint, site) pair using the
        caller's current alias state.  Used to check aliasing at opaque call sites
        where the callee body is unavailable.
        """
        result = []
        for arg in args:
            hint = self._unwrap_ptr_ident(arg) or '<arg>'
            site = self._resolve_site(arg, hint, file, line)
            result.append((hint, site))
        return result

    def _build_call_ctx(self, func: fast.FunctionDef, call_node: fast.FunctionCall) -> tuple:
        """
        Build a call context tuple for a call site.

        For each pointer parameter of the callee (in declaration order), resolve
        the corresponding argument expression to a site string using the caller's
        current alias state.  Parameters with no corresponding argument (variadics,
        missing args) get 'unknown'.  Non-pointer parameters are skipped so the
        tuple length equals the number of pointer parameters only.

        The tuple is used as a cache key: the callee is re-analysed only when a
        new distinct context (different set of argument sites) is seen.
        """
        ptr_params = [p for p in (func.parameters or []) if p.name and _is_pointer_type(p.type_spec)]
        if not ptr_params:
            return ()

        args = list(call_node.arguments or [])

        # build a positional index: callee param index -> argument expression
        # we need to map pointer-param position back to the full parameter list
        # position so we can select the right argument by index
        full_params = list(func.parameters or [])
        ctx = []
        for ptr_param in ptr_params:
            # find this param's position in the full parameter list
            full_idx = next((i for i, p in enumerate(full_params) if p.name == ptr_param.name), None)
            if full_idx is not None and full_idx < len(args):
                site = self._resolve_site(args[full_idx], ptr_param.name,
                                          _node_file(call_node), _node_line(call_node))
            else:
                site = 'unknown'
            ctx.append(site)
        return tuple(ctx)

    def _resolve_ffree_arg(self, arg) -> str:
        """
        Resolve the argument to ffree() to a heap site string.
        Handles: plain Identifier, @x (AddressOf), cast(x), long(x), u64(x).
        ffree takes a numeric address -- the pointer is often cast before passing.
        """
        # plain identifier: ffree(ptr)
        if isinstance(arg, fast.Identifier):
            info = self.alias._find_ptr(arg.name)
            return info.site if info else 'unknown'
        # cast: ffree(long(argv)) or ffree((u64)argv)
        if isinstance(arg, fast.CastExpression):
            return self._resolve_ffree_arg(arg.expression)
        # function call cast like long(argv) -- FunctionCall with type name
        if isinstance(arg, fast.FunctionCall) and isinstance(arg.name, str):
            if arg.arguments:
                return self._resolve_ffree_arg(arg.arguments[0])
        # address-of: ffree(@argv) -- @argv gives address of the pointer variable
        # the pointer itself is what was malloc'd
        if isinstance(arg, fast.AddressOf):
            inner = arg.expression
            if isinstance(inner, fast.Identifier):
                info = self.alias._find_ptr(inner.name)
                #import sys as _sys; _sys.stderr.write(f'[FBC DEBUG] resolve_ffree_arg @{inner.name!r}: info={info!r}\n'); _sys.stderr.flush()
                return info.site if info else 'unknown'
        # type convert: long(argv), u64(argv) etc.
        if isinstance(arg, fast.TypeConvertExpression):
            return self._resolve_ffree_arg(arg.expression)
        # arr[i] -- if arr is known to hold heap sites, return and remove one
        # This handles the pattern: argv[k] = fmalloc(...) then ffree(argv[k])
        if isinstance(arg, fast.ArrayAccess):
            base = arg.array
            if isinstance(base, fast.Identifier):
                arr_name = base.name
                sites = self._array_heap_sites.get(arr_name)
                if sites:
                    site = next(iter(sites))
                    sites.discard(site)
                    return site
        return 'unknown'

    def _resolve_site_via_fvm(self, expr, var_name: str, file: str, line: int) -> str | None:
        """
        Compile and execute expr through the FVM to recover a site string.
        Results are cached by AST node id.
        """
        if expr is None:
            return None
        key = id(expr)
        if key in self._fvm_cache:
            result = self._fvm_cache[key]
            return result if isinstance(result, str) else None
        if not _FVM_AVAILABLE:
            self._fvm_cache[key] = None
            return None
        try:
            cg = FVMCodegen()
            if self._current_func_node is not None:
                func = self._current_func_node
                for param in (func.parameters or []):
                    cg._alloc_local(param.name)
                body = func.body
                stmts = body.statements if isinstance(body, fast.Block) else ([body] if body else [])
                for stmt in stmts:
                    if isinstance(stmt, fast.VariableDeclaration):
                        cg._alloc_local(stmt.name)
            start = len(cg._instructions)
            cg._visit_expr(expr)
            cg._emit(Instr(Op.HALT, [], 0))
            vm = FluxVM()
            for name, instrs in cg.compiled_functions.items():
                vm.register_function(name, instrs)
            vm.execute(cg._instructions[start:], cg._local_count)
            if not vm.stack:
                self._fvm_cache[key] = None
                return None
            top = vm.stack[-1]
            if top.tag == TTag.PTR:
                slot = int(top.data)
                if slot < cg._local_count:
                    slot_to_name = {v: k for k, v in cg._locals.items()}
                    var = slot_to_name.get(slot)
                    if var:
                        for frame in reversed(self.alias.frames):
                            if var in frame.var_sites:
                                result = frame.var_sites[var]
                                self._fvm_cache[key] = result
                                return result
                        result = _make_stack_site(self.alias.func_name, var, line)
                        self._fvm_cache[key] = result
                        return result
                else:
                    result = f"heap:fvm:{slot}"
                    self._fvm_cache[key] = result
                    return result
            if top.tag == TTag.BYTES:
                name = top.data.decode('utf-8') if isinstance(top.data, (bytes, bytearray)) else str(top.data)
                name = name.strip()
                result = _make_param_site(self.alias.func_name, name)
                self._fvm_cache[key] = result
                return result
            self._fvm_cache[key] = None
            return None
        except Exception:
            self._fvm_cache[key] = None
            return None

    def _resolve_site(self, expr, var_name: str, file: str, line: int) -> str:
        """
        Try to determine what allocation site an expression refers to.
        Returns a site identity string.  Falls back to FVM execution before
        giving up and returning 'unknown'.
        """
        if expr is None:
            return 'unknown'

        # @someVar or @someArray[i] -- address of a stack variable or element
        if isinstance(expr, fast.AddressOf):
            inner = expr.expression
            if isinstance(inner, fast.Identifier):
                target_name = inner.name
                for frame in reversed(self.alias.frames):
                    if target_name in frame.var_sites:
                        return frame.var_sites[target_name]
                return _make_stack_site(self.alias.func_name, target_name, line)
            # @arr[i] -- treat as address of the base array
            if isinstance(inner, fast.ArrayAccess):
                base = inner.array
                if isinstance(base, fast.Identifier):
                    target_name = base.name
                    for frame in reversed(self.alias.frames):
                        if target_name in frame.var_sites:
                            return frame.var_sites[target_name]
                    return _make_stack_site(self.alias.func_name, target_name, line)
            return self._resolve_site_via_fvm(expr, var_name, file, line) or 'unknown'

        # fmalloc() call
        if _is_fmalloc(expr):
            return _make_heap_site(self.alias.func_name, _node_line(expr))

        # ffree() -- site resolution returns unknown; side effect handled in _walk_expr
        if _is_ffree(expr):
            return 'unknown'

        # pointer arithmetic -- derived from base
        if isinstance(expr, fast.BinaryOp) and expr.operator in (Operator.ADD, Operator.SUB):
            base_site = self._resolve_site(expr.left, var_name, file, line)
            if base_site != 'unknown':
                return f"derived:{base_site}"
            right_site = self._resolve_site(expr.right, var_name, file, line)
            if right_site != 'unknown':
                return right_site
            return self._resolve_site_via_fvm(expr, var_name, file, line) or 'unknown'

        # identifier -- copy the site from the existing pointer
        if isinstance(expr, fast.Identifier):
            info = self.alias._find_ptr(expr.name)
            if info:
                site = info.site
                if site in self.alias.freed_sites:
                    return f"freed:{site}"
                return site
            # not a tracked pointer -- check var_sites for stack arrays
            for frame in reversed(self.alias.frames):
                if expr.name in frame.var_sites:
                    return frame.var_sites[expr.name]
            return self._resolve_site_via_fvm(expr, var_name, file, line) or 'unknown'

        # cast / type convert -- mark as derived to avoid false alias with original
        # exception: a cast directly wrapping fmalloc is a fresh allocation and
        # must keep the raw heap: site so ffree can match it
        if isinstance(expr, fast.CastExpression):
            if _is_fmalloc(expr.expression):
                return _make_heap_site(self.alias.func_name, _node_line(expr.expression))
            inner = self._resolve_site(expr.expression, var_name, file, line)
            if inner != 'unknown':
                return f"derived:{inner}"
            return self._resolve_site_via_fvm(expr, var_name, file, line) or 'unknown'
        if isinstance(expr, fast.TypeConvertExpression):
            if _is_fmalloc(expr.expression):
                return _make_heap_site(self.alias.func_name, _node_line(expr.expression))
            inner = self._resolve_site(expr.expression, var_name, file, line)
            if inner != 'unknown':
                return f"derived:{inner}"
            return self._resolve_site_via_fvm(expr, var_name, file, line) or 'unknown'

        # deref -- try FVM before giving up
        if isinstance(expr, fast.PointerDeref):
            return self._resolve_site_via_fvm(expr, var_name, file, line) or 'unknown'

        return self._resolve_site_via_fvm(expr, var_name, file, line) or 'unknown'

    def _eval_index_via_fvm(self, expr) -> int | None:
        """
        Evaluate an expression to a concrete integer via the FVM.
        Results are cached by AST node id so each expression is only executed once.
        """
        if expr is None:
            return None
        # fast path: plain integer literal
        if isinstance(expr, fast.Literal) and isinstance(expr.value, int):
            return expr.value
        # cache check
        key = id(expr)
        if key in self._fvm_cache:
            result = self._fvm_cache[key]
            return result if isinstance(result, int) else None
        if not _FVM_AVAILABLE:
            self._fvm_cache[key] = None
            return None
        try:
            cg = FVMCodegen()
            if self._current_func_node is not None:
                func = self._current_func_node
                for param in (func.parameters or []):
                    cg._alloc_local(param.name)
                body = func.body
                stmts = body.statements if isinstance(body, fast.Block) else ([body] if body else [])
                for stmt in stmts:
                    if isinstance(stmt, fast.VariableDeclaration):
                        cg._alloc_local(stmt.name)
            start = len(cg._instructions)
            cg._visit_expr(expr)
            cg._emit(Instr(Op.HALT, [], 0))
            vm = FluxVM()
            for name, instrs in cg.compiled_functions.items():
                vm.register_function(name, instrs)
            vm.execute(cg._instructions[start:], cg._local_count)
            if not vm.stack:
                self._fvm_cache[key] = None
                return None
            top = vm.stack[-1]
            if top.tag in (TTag.INT, TTag.UINT):
                result = int(top.data)
                self._fvm_cache[key] = result
                return result
            self._fvm_cache[key] = None
            return None
        except Exception:
            self._fvm_cache[key] = None
            return None

    def _eval_size_via_fvm(self, expr) -> int | None:
        """
        Evaluate a size/count expression to a concrete integer via the FVM.
        Unwraps casts and type conversions to reach the underlying value.
        """
        inner = expr
        while isinstance(inner, (fast.CastExpression, fast.TypeConvertExpression)):
            inner = inner.expression
        return self._eval_index_via_fvm(inner)

    def _check_bounds_at_access(self, var_name: str, index_expr, file: str, line: int, write: bool = False):
        """
        Evaluate index_expr to a concrete integer and call alias.check_bounds.
        Silently skips if the index is not statically determinable.
        For stack arrays, var_name is not in ptrs -- look it up via var_sites.
        """
        idx = self._eval_index_via_fvm(index_expr)
        if idx is None:
            return
        # try pointer tracking first (heap allocations)
        info = self.alias._find_ptr(var_name)
        if info is not None:
            self.alias.check_bounds(var_name, idx, file, line, write=write)
            return
        # fall back to var_sites for stack arrays and pointer params with known sizes
        for frame in reversed(self.alias.frames):
            if var_name in frame.var_sites:
                site = frame.var_sites[var_name]
                if site in self.alias.alloc_sizes:
                    size = self.alias.alloc_sizes[site]
                    if size >= 0 and (idx < 0 or idx >= size):
                        kind = 'buffer_overflow' if write else 'out_of_bounds'
                        self.alias.violations.append(Violation(
                            kind=kind,
                            message=(
                                f"array {'write' if write else 'access'} on '{var_name}' at index {idx} is "
                                f"out of bounds (size {size})"
                            ),
                            file=file,
                            line=line,
                            detail=[
                                f"'{var_name}' -> {site} (size {size})",
                                f"index {idx} {'< 0' if idx < 0 else '>= size'}",
                            ]
                        ))
                return

    def _walk_expr(self, node):
        """Walk an expression for side effects (calls, thread spawns, ffree)."""
        if node is None:
            return

        file = _node_file(node)
        line = _node_line(node)

        # fmalloc may be wrapped in a cast: (byte**)fmalloc(...)
        _fmalloc_node = node
        if isinstance(node, (fast.CastExpression, fast.TypeConvertExpression)):
            _fmalloc_node = node.expression
        if _is_fmalloc(_fmalloc_node) and self.check_leaks:
            site = _make_heap_site(self.alias.func_name, _node_line(_fmalloc_node))
            self.alias.record_malloc(site, _node_file(_fmalloc_node), _node_line(_fmalloc_node))
            #import sys as _sys; _sys.stderr.write(f'[FBC DEBUG] record_malloc: site={site!r} func={self.alias.func_name!r}\n'); _sys.stderr.flush()
            # record the allocation size if the argument is statically determinable
            if isinstance(_fmalloc_node, fast.FunctionCall) and _fmalloc_node.arguments:
                size = self._eval_size_via_fvm(_fmalloc_node.arguments[0])
                if size is not None:
                    self.alias.record_alloc_size(site, size)

        if _is_ffree(node) and self.check_leaks:
            if isinstance(node, fast.FunctionCall) and node.arguments:
                arg = node.arguments[0]
                # resolve the argument to a site -- handles Identifier, @x, cast(x), etc.
                freed_site = self._resolve_ffree_arg(arg)
                #import sys as _sys; _sys.stderr.write(f'[FBC DEBUG] ffree: arg type={type(arg).__name__!r} freed_site={freed_site!r} func={self.alias.func_name!r} heap_sites={list(self.alias.heap_sites.keys())!r}\n'); _sys.stderr.flush()
                if freed_site and freed_site != 'unknown':
                    self.alias.record_free(freed_site)
                    self.alias.mark_freed(freed_site, file, line)

        if self.check_threads and _is_thread_spawn(node):
            # look for pointer arguments being passed -- unwrap casts to find identifiers
            args = getattr(node, 'arguments', []) or []

            # find the function-pointer argument -- typically the first arg
            # that resolves to a known function name
            spawned_func_name = None
            for arg in args:
                cand = self._unwrap_ptr_ident(arg)
                if cand and cand in self.cg.funcs:
                    spawned_func_name = cand
                    break
                if cand and cand in self.cg.short_names:
                    spawned_func_name = self.cg.short_names[cand]
                    break

            for arg in args:
                name = self._unwrap_ptr_ident(arg)
                if name:
                    self.alias.check_thread_escape(name, file, line)

            if spawned_func_name and spawned_func_name in self.cg.funcs:
                prev_count = self.cg.spawn_count.get(spawned_func_name, 0)
                self.cg.spawn_count[spawned_func_name] = prev_count + 1

                # walk spawned function under thread context if not done yet under this context
                spawned_func = self.cg.funcs[spawned_func_name]
                spawn_ctx = self._build_call_ctx(spawned_func, node)
                if not self.cg.is_visited(spawned_func_name, spawn_ctx, True):
                    self._check_function(spawned_func, thread_context=True, call_ctx=spawn_ctx)

                # if this function is spawned more than once, its mutable pointer
                # params can race with themselves across concurrent instances
                if prev_count >= 1:
                    spawned_func = self.cg.funcs[spawned_func_name]
                    mutable_ptr_params = [
                        p for p in (spawned_func.parameters or [])
                        if p.name and _is_pointer_type(p.type_spec)
                    ]
                    if mutable_ptr_params:
                        param_names = ', '.join(p.name for p in mutable_ptr_params)
                        self.violations.append(Violation(
                            kind='thread_self_race',
                            message=(
                                f"function '{spawned_func_name}' is spawned as a thread "
                                f"{prev_count + 1} times -- concurrent instances share "
                                f"mutable pointer parameter(s): {param_names}"
                            ),
                            file=file,
                            line=line,
                            detail=[
                                f"each spawn receives a separate pointer value but if "
                                f"those values alias the same allocation site, a data "
                                f"race exists between the concurrent instances"
                            ]
                        ))

        # check any identifier use against thread-escaped sites
        if self.check_threads and isinstance(node, fast.Identifier):
            self._check_ident_escape(node.name, file, line)

        # resolve calls into the call graph
        if isinstance(node, fast.FunctionCall):
            callee_name = node.name if isinstance(node.name, str) else None
            # if the callee is an expression (function pointer), try FVM to resolve it
            if callee_name is None and node.name is not None:
                callee_name = self._resolve_fptr_expr(node.name)
            if callee_name:
                cur_ctx = self._in_thread_context
                resolved = callee_name if callee_name in self.cg.funcs else self.cg.short_names.get(callee_name)
                # never walk into allocator bodies -- their internal heap management
                # would pollute freed_sites and heap_sites with false entries
                base_name = (resolved or callee_name or '').split('__')[-1]
                is_allocator = base_name in self._ALLOCATOR_FUNCS or callee_name in self._ALLOCATOR_FUNCS
                if resolved and not is_allocator:
                    ctx_tuple = self._build_call_ctx(self.cg.funcs[resolved], node)
                    if not self.cg.is_visited(resolved, ctx_tuple, cur_ctx):
                        self._check_function(self.cg.funcs[resolved], thread_context=cur_ctx,
                                             call_ctx=ctx_tuple)
                elif not is_allocator:
                    # try overload index -- call site uses base name, codegen adds arity suffix
                    for mangled in self.cg.overloads.get(callee_name, []):
                        ctx_tuple = self._build_call_ctx(self.cg.funcs[mangled], node)
                        if not self.cg.is_visited(mangled, ctx_tuple, cur_ctx):
                            self._check_function(self.cg.funcs[mangled], thread_context=cur_ctx,
                                                 call_ctx=ctx_tuple)
                    # callee not in call graph (extern, truly-runtime function pointer)
                    # check argument aliasing at the call site in the caller scope
                    if not self.cg.overloads.get(callee_name):
                        arg_sites = self._collect_arg_sites(list(node.arguments or []), file, line)
                        self.alias.check_call_args(arg_sites, file, line)
                    # DEBUG
                    #if not self.cg.overloads.get(callee_name):
                    #    print(f"[FBC DEBUG] unresolved call in {self.alias.func_name!r}: {callee_name!r}")
                # DEBUG
                #elif not resolved:
                #    print(f"[FBC DEBUG] unresolved call: {callee_name!r} -- likely extern or intra-namespace (caller scope not tracked)")
            else:
                # name expression could not be resolved even with FVM -- check args for aliasing
                arg_sites = self._collect_arg_sites(list(node.arguments or []), file, line)
                self.alias.check_call_args(arg_sites, file, line)
                # DEBUG
                #print(f"[FBC DEBUG] unresolvable call expr in {self.alias.func_name!r}: {type(node.name).__name__}")
            for arg in (node.arguments or []):
                self._walk_expr(arg)

        elif isinstance(node, fast.MethodCall):
            self._walk_expr(node.object)
            for arg in (node.arguments or []):
                self._walk_expr(arg)
            # attempt to resolve the method to a known function body
            method_name = getattr(node, 'method_name', None) or getattr(node, 'name', None)
            if method_name:
                obj_hint = self._unwrap_ptr_ident(node.object) or ''
                resolved_method = None
                # try <obj_hint>__<method> (variable name), then short name lookup,
                # then scan all functions whose name ends with __<method>
                candidates = []
                if obj_hint:
                    candidates.append(f"{obj_hint}__{method_name}")
                candidates.append(method_name)
                for candidate in candidates:
                    if candidate in self.cg.funcs:
                        resolved_method = candidate
                        break
                    if candidate in self.cg.short_names:
                        resolved_method = self.cg.short_names[candidate]
                        break
                # scan all functions whose mangled name ends with __<method_name>
                # this covers Type__method when obj_hint is a variable name not the type
                if not resolved_method:
                    suffix = f"__{method_name}"
                    for mangled in self.cg.funcs:
                        if mangled.endswith(suffix):
                            resolved_method = mangled
                            break
                #import sys as _sys; _sys.stderr.write(f'[FBC DEBUG] MethodCall obj={obj_hint!r} method={method_name!r} resolved={resolved_method!r}\n'); _sys.stderr.flush()
                # if static name lookup failed, try FVM on the full method expression
                if not resolved_method:
                    resolved_method = self._resolve_fptr_expr(node)
                if resolved_method:
                    synth = _SyntheticCall(resolved_method, list(node.arguments or []),
                                           _node_file(node), _node_line(node))
                    ctx_tuple = self._build_call_ctx(self.cg.funcs[resolved_method], synth)
                    cur_ctx = self._in_thread_context
                    if not self.cg.is_visited(resolved_method, ctx_tuple, cur_ctx):
                        self._check_function(self.cg.funcs[resolved_method],
                                             thread_context=cur_ctx, call_ctx=ctx_tuple)
                else:
                    # callee not resolvable -- check argument aliasing at the call site
                    arg_sites = self._collect_arg_sites(list(node.arguments or []), file, line)
                    self.alias.check_call_args(arg_sites, file, line)

        elif isinstance(node, fast.BinaryOp):
            self._walk_expr(node.left)
            self._walk_expr(node.right)

        elif isinstance(node, fast.UnaryOp):
            self._walk_expr(node.operand)

        elif isinstance(node, fast.AddressOf):
            self._walk_expr(node.expression)

        elif isinstance(node, fast.PointerDeref):
            # check for use-after-thread-escape
            if self.check_threads and isinstance(node.pointer, fast.Identifier):
                self.alias.check_use_after_escape(node.pointer.name, file, line)
            # check for use-after-free
            if isinstance(node.pointer, fast.Identifier):
                #import sys as _sys; _sys.stderr.write(f'[FBC DEBUG] PointerDeref: ptr={node.pointer.name!r} freed_sites={list(self.alias.freed_sites.keys())!r}\n'); _sys.stderr.flush()
                self.alias.check_use_after_free(node.pointer.name, file, line)
            self._walk_expr(node.pointer)

        elif isinstance(node, fast.MemberAccess):
            self._walk_expr(node.object)

        elif isinstance(node, fast.ArrayAccess):
            # check for access to thread-escaped pointer
            if self.check_threads and isinstance(node.array, fast.Identifier):
                self.alias.check_use_after_escape(node.array.name, file, line)
            # check for use-after-free
            if isinstance(node.array, fast.Identifier):
                self.alias.check_use_after_free(node.array.name, file, line)
            # check for statically-determinable out-of-bounds index
            if isinstance(node.array, fast.Identifier):
                self._check_bounds_at_access(node.array.name, node.index, file, line)
            self._walk_expr(node.array)
            self._walk_expr(node.index)

        elif isinstance(node, fast.CastExpression):
            self._walk_expr(node.expression)

        elif isinstance(node, fast.TypeConvertExpression):
            self._walk_expr(node.expression)

        elif isinstance(node, fast.IfExpression):
            self._walk_expr(node.condition)
            self._walk_expr(node.then_expr)
            self._walk_expr(node.else_expr)

        elif isinstance(node, fast.TernaryOp):
            self._walk_expr(node.condition)
            self._walk_expr(node.true_expr)
            self._walk_expr(node.false_expr)

        elif isinstance(node, fast.Assignment):
            self._walk_expr(node.value)
            # check lvalue target for escaped site access
            if self.check_threads:
                if isinstance(node.target, fast.Identifier):
                    self._check_ident_escape(node.target.name, file, line)
                elif isinstance(node.target, fast.ArrayAccess):
                    arr = node.target.array
                    if isinstance(arr, fast.Identifier):
                        self._check_ident_escape(arr.name, file, line)
            # check lvalue target for use-after-free
            if isinstance(node.target, fast.PointerDeref):
                inner = node.target.pointer
                if isinstance(inner, fast.Identifier):
                    self.alias.check_use_after_free(inner.name, file, line)
                    self.alias.check_write_alias(inner.name, file, line)
            elif isinstance(node.target, fast.ArrayAccess):
                arr = node.target.array
                if isinstance(arr, fast.Identifier):
                    self.alias.check_use_after_free(arr.name, file, line)
                    self.alias.check_write_alias(arr.name, file, line)
                    self._check_bounds_at_access(arr.name, node.target.index, file, line, write=True)
                    # arr[i] = ptr -- track heap sites stored into arrays so
                    # ffree(arr[j]) can resolve back to the original heap site
                    if self.check_leaks and isinstance(node.value, fast.Identifier):
                        info = self.alias._find_ptr(node.value.name)
                        if info and info.site in self.alias.heap_sites:
                            if arr.name not in self._array_heap_sites:
                                self._array_heap_sites[arr.name] = set()
                            self._array_heap_sites[arr.name].add(info.site)
            # if target is a known pointer, update its site
            if isinstance(node.target, fast.Identifier):
                existing = self.alias._find_ptr(node.target.name)
                if existing is not None:
                    new_site = self._resolve_site(node.value, node.target.name,
                                                  _node_file(node), _node_line(node))
                    source_var = node.value.name if isinstance(node.value, fast.Identifier) else None
                    self.alias.assign_ptr(node.target.name, new_site, True,
                                          _node_file(node), _node_line(node), source_var=source_var)

        elif isinstance(node, fast.CompoundAssignment):
            self._walk_expr(node.value)

# ---------------------------------------------------------------------------
# File parsing
# ---------------------------------------------------------------------------

def parse_file(path: str):
    """Returns (Program, line_map) where line_map[i] = (filename, orig_line) for merged line i+1."""
    platform_macros = build_compiler_macros()
    preprocessor = FXPreprocessor(path, compiler_constants=platform_macros)
    source = preprocessor.process()
    line_map = preprocessor.line_map  # list of (filename, orig_line_1based)
    lexer = FluxLexer(source)
    tokens = lexer.tokenize()
    parser = FluxParser(tokens)
    return parser.parse(), line_map

def collect_fx_files(path: str) -> list[str]:
    p = Path(path)
    if p.is_file():
        return [str(p)]
    return sorted(str(f) for f in p.rglob('*.fx'))

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description='Flux Borrow Checker -- static pointer safety analysis'
    )
    parser.add_argument('target', help='File or directory to check')
    parser.add_argument('--entry',    default='FRTStartup',
                        help='Entry point function name (default: FRTStartup)')
    parser.add_argument('--warn',     action='store_true',
                        help='Treat violations as warnings instead of errors')
    parser.add_argument('--threads',  action='store_true',
                        help='Check thread safety (pointer escape across spawns)')
    parser.add_argument('--leaks',    action='store_true',
                        help='Check for heap leaks (unmatched fmalloc/ffree)')
    parser.add_argument('--json',     action='store_true',
                        help='Machine-readable JSON output')
    parser.add_argument('--no-color', action='store_true',
                        help='Disable ANSI color output')
    args = parser.parse_args()

    use_color = not args.no_color and sys.stderr.isatty()

    # --- collect and parse files ---
    fx_files = collect_fx_files(args.target)
    if not fx_files:
        print(f"[FBC] No .fx files found in: {args.target}")
        sys.exit(2)

    if not args.json:
        print(f"[FBC] Checking {len(fx_files)} file(s), entry: {args.entry}")

    programs = []
    line_maps = []
    parse_errors = []
    for fx in fx_files:
        try:
            prog, line_map = parse_file(fx)
            programs.append((fx, prog))
            line_maps.append(line_map)
        except Exception as e:
            parse_errors.append((fx, str(e)))
            if not args.json:
                print(f"[FBC] Parse error in {fx}: {e}", file=sys.stderr)

    if not programs:
        print("[FBC] No files could be parsed.")
        sys.exit(2)

    # merge line maps -- since we parse one file at a time (preprocessor merges imports)
    # we only have one line_map per input file
    combined_line_map = line_maps[0] if line_maps else []

    # --- build call graph ---
    cg = CallGraph()
    for fx, prog in programs:
        cg.collect(prog)

    if not args.json:
        print(f"[FBC] {len(cg.funcs)} function(s) found")

    # --- run borrow checker ---
    checker = BorrowChecker(
        call_graph=cg,
        entry=args.entry,
        check_threads=args.threads,
        check_leaks=args.leaks,
        line_map=combined_line_map,
    )
    checker.run()

    all_violations = checker.violations

    # --- report ---
    mode = 'warn' if args.warn else 'error'
    print_violations(all_violations, mode=mode, use_color=use_color,
                     json_out=args.json)
    print_summary(all_violations, files_checked=len(fx_files),
                  funcs_checked=checker.funcs_checked,
                  use_color=use_color, json_out=args.json)

    if all_violations and not args.warn:
        sys.exit(1)
    sys.exit(0)


if __name__ == '__main__':
    main()