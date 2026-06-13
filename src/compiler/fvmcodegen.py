#!/usr/bin/env python3
"""
Flux VM Codegen (fvmcodegen.py)
Compiles Flux AST nodes inside comptime blocks to fvm.py bytecode.

This mirrors fcodegen.py's visitor pattern but targets the FluxVM
instead of LLVM IR. It does not use llvmlite, ir.IRBuilder, or
ir.Module in any way.

Copyright (C) 2026 Karac V. Thweatt
"""

from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple

from fvm import Op, TTag, Val, Instr
from fast import (
    ASTNode,
    ComptimeBlock, EmitFlux,
    VariableDeclaration,
    TypeDeclaration,
    Assignment, CompoundAssignment,
    BinaryOp, UnaryOp,
    Literal, Identifier, StringLiteral, FStringLiteral,
    FunctionCall, MethodCall, MemberAccess,
    ArrayLiteral,
    AddressOf, CastExpression, TypeConvertExpression,
    PointerDeref,
    InExpression,
    SizeOf,
    TypeOf,
    IfStatement,
    WhileLoop, DoLoop, DoWhileLoop,
    ForLoop,
    ReturnStatement,
    BreakStatement, ContinueStatement, EscapeStatement,
    LabelStatement, GotoStatement, JumpStatement,
    ExpressionStatement,
    Block,
    ArrayAccess,
    SwitchStatement, Case,
    FunctionDef, FunctionDefStatement,
    FunctionPointerDeclaration,
    TypeFuncDef, TypeFuncCall,
    NamespaceDef, NamespaceDefStatement,
    StructDef, StructDefStatement, StructMember, StructInstance, StructLiteral,
    StructFieldAccess, StructFieldAssign, StructRecast,
    UnionDef, UnionDefStatement,
    ConstraDef,
    EnumDef, EnumDefStatement,
    macroDefStatement, macroCall,
    ExternBlock,
    FluxVMBlock,
    UsingStatement, NotUsingStatement,
    InlineAsm,
)
from ftypesys import DataType, Operator


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _datatype_to_ttag(dt: DataType) -> TTag:
    """Map a Flux DataType to the closest VM TTag."""
    _map = {
        DataType.SINT:    TTag.INT,
        DataType.UINT:   TTag.UINT,
        DataType.SLONG:   TTag.LONG,
        DataType.ULONG:  TTag.ULONG,
        DataType.FLOAT:  TTag.FLOAT,
        DataType.DOUBLE: TTag.DOUBLE,
        DataType.BOOL:   TTag.BOOL,
        DataType.BYTE:   TTag.BYTE,
        DataType.CHAR:   TTag.CHAR,
    }
    return _map.get(dt, TTag.INT)


# Integer/float type aliases defined via `as` that must not be treated as structs.
_PRIM_ALIAS_TTAG: dict = {
    'i8':  TTag.INT,  'i16': TTag.INT,  'i32': TTag.INT,  'i64': TTag.LONG,
    'u8':  TTag.UINT, 'u16': TTag.UINT, 'u32': TTag.UINT, 'u64': TTag.ULONG,
    'f32': TTag.FLOAT, 'f64': TTag.DOUBLE,
    'size_t': TTag.ULONG, 'ssize_t': TTag.LONG,
    'uintptr_t': TTag.ULONG, 'intptr_t': TTag.LONG,
    'ptrdiff_t': TTag.LONG,
}

def _prim_alias_ttag(name: str):
    """Return TTag for a known integer/float alias, or None if it is a real struct type."""
    t = _PRIM_ALIAS_TTAG.get(name)
    if t is not None:
        return t
    # data{N} aliases: i<bits> / u<bits> patterns
    if name and name[0] in ('i', 'u') and name[1:].isdigit():
        return TTag.LONG if name[0] == 'i' else TTag.ULONG
    return None


def _instr(op: Op, *operands) -> Instr:
    return Instr(op, list(operands))


# ---------------------------------------------------------------------------
# Codegen result
# ---------------------------------------------------------------------------

class ComptimeBytecode:
    """Holds the flat instruction list and local count produced for a comptime block."""
    def __init__(self, instructions: List[Instr], local_count: int):
        self.instructions = instructions
        self.local_count   = local_count


# ---------------------------------------------------------------------------
# FVMCodegen visitor
# ---------------------------------------------------------------------------

class FVMCodegenError(Exception):
    """Carries both a message and the AST node that caused the failure."""
    def __init__(self, message: str, node=None):
        loc = ''
        self.override_src_text = None
        if node is not None:
            line = getattr(node, 'source_line', None)
            col  = getattr(node, 'source_col',  None)
            if line:
                loc = f' [{line}:{col}]'
            # For InlineAsm, build a rich display from the node's own body/constraints
            from fast import InlineAsm as _IA
            if isinstance(node, _IA):
                prefix = 'volatile asm' if node.is_volatile else 'asm'
                body_indented = '\n'.join('    ' + l for l in node.body.splitlines())
                constraints = f' : {node.constraints}' if node.constraints else ''
                self.override_src_text = f'{prefix}\n{{\n{body_indented}\n}}{constraints};'
        super().__init__(message + loc)
        self.source_node = node


class FVMCodegen:
    """
    Visits a ComptimeBlock AST node and emits FluxVM bytecode.

    Usage:
        cg = FVMCodegen()
        bc = cg.compile(node, captured_scope)
        vm.execute(bc.instructions, bc.local_count)
    """

    def __init__(self, known_functions: Dict[str, list] = None,
                 known_struct_layouts: Dict[str, Any] = None):
        self._instructions: List[Instr] = []
        # Maps variable name -> local slot index
        self._locals: Dict[str, int] = {}
        self._local_count: int = 0
        # Loop-level break/continue patch lists (list of instruction indices)
        self._loop_patches: List[Tuple[int, str]] = []
        # Compiled comptime functions: name -> List[Instr]
        self.compiled_functions: Dict[str, List[Instr]] = {}
        # Previously accumulated comptime functions (from prior blocks) for lookup
        self._known_functions: Dict[str, list] = known_functions or {}
        # Maps local variable name -> declared type name (for type function resolution)
        self._local_types: Dict[str, str] = {}
        # Struct layouts computed from StructDef nodes: name -> StructLayout
        self._struct_layouts: Dict[str, Any] = dict(known_struct_layouts or {})
        # Label name -> instruction index (for goto resolution)
        self._labels: Dict[str, int] = {}
        # Goto patches: list of (instr_idx, label_name) to resolve after body
        self._goto_patches: List[Tuple[int, str]] = []
        # Name of the enclosing <~ strict-recursive function, or None.
        # When set, self-calls and returns emit TAIL_SELF instead of CALL/RET.
        self._tail_call_self: Optional[str] = None
        self._tail_call_argc: int = 0
        # Active using-namespaces (:: replaced with __) for name resolution
        self._using_namespaces: List[str] = []
        self._excluded_namespaces: set = set()
        # Known enum type names (must not be treated as structs)
        self._enum_names: set = set()
        # Current source line being compiled, stamped onto emitted instructions
        self._current_src_line: int = 0
        # Expression macro definitions registered at comptime codegen time
        self._macro_table: dict = {}
        # Names declared with `local` storage class - cannot escape scope
        self._local_vars: set = set()
        # Full TypeSystem for declared locals, for sizeof/typeof resolution
        self._local_typespecs: dict = {}
        # Heap-allocated variables: name -> (TTag, byte_size) for auto-deref on read
        self._heap_vars: dict = {}
        # Names declared at the top level of the comptime block (accessible to
        # nested function definitions via GLOBAL_GET / GLOBAL_SET).
        self._block_globals: set = set()
        # When True, this codegen is compiling a nested function body and should
        # use GLOBAL_GET/SET for names listed in _outer_globals.
        self._outer_globals: set = set()

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def compile(
        self,
        node: ComptimeBlock,
        captured_scope: Dict[str, Val] = None,
    ) -> ComptimeBytecode:
        """
        Compile a ComptimeBlock to VM bytecode.

        captured_scope: variables from the enclosing Flux scope, captured by
        value (read-only).  Each entry is pre-allocated as a local slot and
        initialised with a PUSH / LOCAL_SET pair.
        """
        captured_scope = captured_scope or {}

        # Pre-allocate captured scope variables as read-only locals
        for name, val in captured_scope.items():
            slot = self._alloc_local(name)
            self._emit(_instr(Op.PUSH, val))
            self._emit(_instr(Op.LOCAL_SET, slot))

        # Compile the body
        self._visit_body(node.body)

        # Resolve any remaining forward goto patches
        self._resolve_goto_patches()

        # Terminate with HALT
        self._emit(_instr(Op.HALT))

        return ComptimeBytecode(self._instructions, self._local_count)

    # ------------------------------------------------------------------
    # Emit helpers
    # ------------------------------------------------------------------

    def _emit(self, instr: Instr) -> int:
        """Append an instruction, return its index."""
        if self._current_src_line and not instr.src_line:
            instr.src_line = self._current_src_line
        idx = len(self._instructions)
        self._instructions.append(instr)
        return idx

    def _current_ip(self) -> int:
        return len(self._instructions)

    def _alloc_local(self, name: str) -> int:
        if name not in self._locals:
            self._locals[name] = self._local_count
            self._local_count += 1
        return self._locals[name]

    def _fresh_tmp(self) -> str:
        """Return a unique temp-variable name that cannot collide with user identifiers."""
        n = self._local_count
        return f'__tmp_{n}__'

    def _patch_at(self, idx: int, new_op: Op, addr: int):
        """Replace the instruction at idx with new_op targeting addr."""
        self._instructions[idx] = _instr(new_op, addr)

    # ------------------------------------------------------------------
    # Body / statement dispatch
    # ------------------------------------------------------------------

    def _visit_body(self, stmts: list):
        from fast import ArrayLiteral as _AL
        _unpack_targets = {DataType.SINT, DataType.UINT, DataType.SLONG, DataType.ULONG,
                           DataType.BYTE, DataType.CHAR}

        # Pre-scan: find unpack groups. Pattern: one or more None-init VariableDeclarations
        # of the same type immediately followed by an ArrayLiteral([src]) VariableDeclaration.
        # Mark each group as (start_idx, end_idx_inclusive, src_expr).
        unpack_ranges: dict = {}  # start_idx -> (end_idx, src_expr)
        skip_indices: set = set()
        j = 0
        while j < len(stmts):
            s = stmts[j]
            if (isinstance(s, VariableDeclaration) and
                    s.initial_value is not None and
                    isinstance(s.initial_value, _AL) and
                    not s.initial_value.is_string and
                    len(s.initial_value.elements) == 1 and
                    s.type_spec is not None and
                    not s.type_spec.is_array and
                    s.type_spec.base_type in _unpack_targets):
                # Look back for None-init declarations of the same type
                k = j - 1
                while (k >= 0 and k not in skip_indices and
                       isinstance(stmts[k], VariableDeclaration) and
                       stmts[k].initial_value is None and
                       stmts[k].type_spec is not None and
                       stmts[k].type_spec.base_type == s.type_spec.base_type):
                    k -= 1
                group_start = k + 1
                if group_start < j:
                    unpack_ranges[group_start] = (j, s.initial_value.elements[0])
                    for idx in range(group_start, j + 1):
                        skip_indices.add(idx)
            j += 1

        i = 0
        while i < len(stmts):
            if i in unpack_ranges:
                end_idx, src_expr = unpack_ranges[i]
                group = stmts[i:end_idx + 1]
                self._emit_unpack(group, src_expr)
                i = end_idx + 1
            elif i in skip_indices:
                i += 1
            else:
                self._visit_stmt(stmts[i])
                i += 1

    def _visit_stmt(self, node: ASTNode):
        if node is None:
            return
        src = getattr(node, 'source_line', 0)
        if src:
            self._current_src_line = src
        t = type(node)
        if t is VariableDeclaration:     self._visit_var_decl(node)
        elif t is TypeDeclaration:       self._visit_type_decl(node)
        elif t is Assignment:            self._visit_assignment(node)
        elif t is CompoundAssignment:    self._visit_compound_assign(node)
        elif t is ExpressionStatement:   self._visit_expr_stmt(node)
        elif t is IfStatement:           self._visit_if(node)
        elif t is ForLoop:               self._visit_for(node)
        elif t is WhileLoop:             self._visit_while(node)
        elif t is DoLoop:                self._visit_do(node)
        elif t is DoWhileLoop:           self._visit_do_while(node)
        elif t is ReturnStatement:       self._visit_return(node)
        elif t is BreakStatement:        self._visit_break(node)
        elif t is EscapeStatement:       self._visit_escape(node)
        elif t is ContinueStatement:     self._visit_continue(node)
        elif t is Block:                 self._visit_body(node.statements)
        elif t is SwitchStatement:       self._visit_switch(node)
        elif t is FunctionDef:           self._visit_function_def(node)
        elif t is FunctionDefStatement:  self._visit_function_def(node.function_def)
        elif t is FunctionPointerDeclaration: self._visit_fp_decl(node)
        elif t is TypeFuncDef:           self._visit_type_func_def(node)
        elif t is NamespaceDef:          self._visit_namespace_def(node)
        elif t is NamespaceDefStatement: self._visit_namespace_def(node.namespace_def)
        elif t is StructDef:             self._visit_struct_def(node)
        elif t is StructDefStatement:    self._visit_struct_def(node.struct_def)
        elif t is StructFieldAssign:     self._visit_struct_field_assign(node)
        elif t is UnionDef:              self._visit_union_def(node)
        elif t is UnionDefStatement:     self._visit_union_def(node.union_def)
        elif t is ConstraDef:            pass  # compile-time only, no VM emission
        elif t is macroDefStatement:     self._macro_table[node.macro_def.name] = node.macro_def
        elif t.__name__ in ('macroDef', 'ExportBlock'): pass  # no VM emission
        elif t is ExternBlock:           self._visit_extern_block(node)
        elif t is EnumDef:               self._visit_enum_def(node)
        elif t is EnumDefStatement:      self._visit_enum_def(node.enum_def)
        elif t is LabelStatement:        self._visit_label(node)
        elif t is GotoStatement:         self._visit_goto(node)
        elif t is JumpStatement:         self._visit_jump(node)
        elif t is EmitFlux:              self._visit_emitflux(node)
        elif t is FluxVMBlock:           self._visit_fluxvm_block(node)
        elif t is ComptimeBlock:         self._visit_body(node.body)
        elif isinstance(node, list):     self._visit_body(node)
        elif t is UsingStatement:        self._visit_using(node)
        elif t is NotUsingStatement:     self._visit_not_using(node)
        else:
            raise FVMCodegenError(
                f'fvmcodegen: unsupported node in comptime: {type(node).__name__}',
                node
            )

    # ------------------------------------------------------------------
    # Variable declaration
    # ------------------------------------------------------------------

    def _visit_type_decl(self, node: TypeDeclaration):
        """
        Type alias declaration: data{8} as nbyte; or int as myint;
        At comptime this has no runtime effect — register the alias name so
        that subsequent variable declarations using it resolve correctly.
        If an initial value is present treat it like a variable declaration.
        """
        if node.type_spec is not None:
            bt = node.type_spec.base_type
            if node.type_spec.custom_typename:
                self._local_types[node.name] = node.type_spec.custom_typename
            elif bt is not None and bt == DataType.DATA and node.type_spec.bit_width:
                self._local_types[node.name] = f'__data_{node.type_spec.bit_width}'
            elif bt is not None:
                self._local_types[node.name] = bt.value if hasattr(bt, 'value') else str(bt)
        if node.initial_value is not None:
            slot = self._alloc_local(node.name)
            self._visit_expr(node.initial_value)
            self._emit(_instr(Op.LOCAL_SET, slot))

    def _visit_var_decl(self, node: VariableDeclaration):
        slot = self._alloc_local(node.name)
        # Track local storage class — local variables cannot escape scope
        if (node.type_spec is not None and
                getattr(node.type_spec, 'is_local', False)):
            self._local_vars.add(node.name)
        # Handle heap storage class — allocate on VM heap, slot holds PTR, reads auto-deref
        from ftypesys import StorageClass as _SC
        from fast import ArrayLiteral as _AL
        if (node.type_spec is not None and
                getattr(node.type_spec, 'storage_class', None) == _SC.HEAP):
            ts = node.type_spec
            if ts.is_array:
                # Array: allocate count * elem_size bytes
                arr_size = ts.array_size
                if hasattr(arr_size, 'value'):
                    arr_size = int(arr_size.value)
                else:
                    arr_size = int(arr_size)
                elem_bits = self._type_bit_width_base(ts.base_type, ts)
                elem_bytes = max(1, elem_bits // 8)
                elem_ttag = _datatype_to_ttag(ts.base_type)
                total_bytes = arr_size * elem_bytes
                self._heap_vars[node.name] = (elem_ttag, elem_bytes, arr_size)
                self._emit(_instr(Op.PUSH, Val(TTag.UINT, total_bytes)))
                self._emit(_instr(Op.ALLOC))   # PTR to base
                if node.initial_value is not None and isinstance(node.initial_value, _AL):
                    # Store each element at ptr + i*elem_bytes
                    for i, elem in enumerate(node.initial_value.elements):
                        self._emit(_instr(Op.DUP))               # ptr
                        self._emit(_instr(Op.PUSH, Val(TTag.UINT, i * elem_bytes)))
                        self._emit(_instr(Op.ADD))               # ptr + offset
                        self._visit_expr(elem)
                        self._emit(_instr(Op.STORE, elem_ttag, elem_bytes))
                self._emit(_instr(Op.LOCAL_SET, slot))
            else:
                bits      = self._type_bit_width(ts)
                byte_size = max(1, bits // 8)
                ttag      = self._type_ttag_from_ts(ts)
                self._heap_vars[node.name] = (ttag, byte_size)
                self._emit(_instr(Op.PUSH, Val(TTag.UINT, byte_size)))
                self._emit(_instr(Op.ALLOC))
                if node.initial_value is not None:
                    self._emit(_instr(Op.DUP))
                    self._visit_expr(node.initial_value)
                    self._emit(_instr(Op.STORE, ttag, byte_size))
                self._emit(_instr(Op.LOCAL_SET, slot))
            return
        # Handle singinit storage class — initialize once, persist in _globals
        from ftypesys import StorageClass as _SC2
        if (node.type_spec is not None and
                getattr(node.type_spec, 'storage_class', None) == _SC2.SINGINIT):
            guard_name = f'__singinit_guard__{node.name}'
            # Only initialize if guard not already set
            # Emit: if GLOBAL_GET guard == 0, initialize and set guard
            done_patch_idx = None
            self._emit(_instr(Op.GLOBAL_GET, guard_name))
            self._emit(_instr(Op.PUSH, Val(TTag.INT, 0)))
            self._emit(_instr(Op.CMP_EQ))
            jnf_idx = self._emit(_instr(Op.JNF, 0))  # skip init if already done
            # Init block: evaluate initializer and store in globals
            if node.initial_value is not None:
                self._visit_expr(node.initial_value)
            else:
                ttag2 = self._type_ttag_from_ts(node.type_spec)
                self._emit(_instr(Op.PUSH, Val(ttag2, 0)))
            self._emit(_instr(Op.DUP))
            self._emit(_instr(Op.LOCAL_SET, slot))
            self._emit(_instr(Op.GLOBAL_SET, node.name))
            self._emit(_instr(Op.PUSH, Val(TTag.INT, 1)))
            self._emit(_instr(Op.GLOBAL_SET, guard_name))
            jmp_idx = self._emit(_instr(Op.JMP, 0))
            # Done block: load from globals into local slot
            done_ip = self._current_ip()
            self._patch_at(jnf_idx, Op.JNF, done_ip)
            self._emit(_instr(Op.GLOBAL_GET, node.name))
            self._emit(_instr(Op.LOCAL_SET, slot))
            after_ip = self._current_ip()
            self._patch_at(jmp_idx, Op.JMP, after_ip)
            self._block_globals.add(node.name)
            self._block_globals.add(guard_name)
            return

        # Record the type name and full typespec for type function resolution
        if node.type_spec is not None:
            ts = node.type_spec
            self._local_typespecs[node.name] = ts
            if ts.custom_typename:
                self._local_types[node.name] = ts.custom_typename
            elif ts.base_type is not None:
                self._local_types[node.name] = str(ts.base_type.value) if hasattr(ts.base_type, 'value') else str(ts.base_type)
        if node.initial_value is not None:
            # Pack expression: scalar_type var = [a, b, ...] packs elements into an integer.
            # Detect this when the target type is a scalar integer and the initial value
            # is an ArrayLiteral that is not a string.
            from fast import ArrayLiteral as _AL
            _pack_targets = {DataType.SINT, DataType.UINT, DataType.SLONG, DataType.ULONG,
                             DataType.BYTE, DataType.CHAR}
            if (node.type_spec is not None and
                    not node.type_spec.is_array and
                    isinstance(node.initial_value, _AL) and
                    not node.initial_value.is_string and
                    node.type_spec.base_type in _pack_targets):
                self._emit_pack(node.initial_value, node.type_spec)
            else:
                self._visit_expr(node.initial_value)
        else:
            # Zero-initialise (all Flux variables are zero-init by default)
            if (node.type_spec is not None and
                    node.type_spec.custom_typename is not None):
                _ctn = node.type_spec.custom_typename
                _prim = _prim_alias_ttag(_ctn)
                if _prim is not None:
                    self._emit(_instr(Op.PUSH, Val(_prim, 0)))
                elif _ctn in self._enum_names:
                    self._emit(_instr(Op.ENUM_NEW, _ctn))
                else:
                    # Emit STRUCT_NEW even for types not yet in _struct_layouts --
                    # layout resolved at VM runtime after compiler.import.* runs
                    self._emit(_instr(Op.STRUCT_NEW, _ctn))
            else:
                ttag = _datatype_to_ttag(
                    node.type_spec.base_type if node.type_spec else DataType.SINT
                )
                self._emit(_instr(Op.PUSH, Val(ttag, 0)))
        # Mirror to VM globals so nested function bodies can access this variable.
        self._block_globals.add(node.name)
        self._emit(_instr(Op.DUP))
        self._emit(_instr(Op.LOCAL_SET, slot))
        self._emit(_instr(Op.GLOBAL_SET, node.name))

    # ------------------------------------------------------------------
    # Assignment
    # ------------------------------------------------------------------

    def _visit_assignment(self, node: Assignment):
        if isinstance(node.target, Identifier):
            name = node.target.name
            if name in self._outer_globals:
                self._visit_expr(node.value)
                self._emit(_instr(Op.GLOBAL_SET, name))
                return
            # Any assignment at comptime scope is also a global so inner
            # function bodies (compiled as separate fn_cg instances) can
            # access it via GLOBAL_GET.
            self._block_globals.add(name)
            self._visit_expr(node.value)
            slot = self._alloc_local(name)
            self._emit(_instr(Op.DUP))
            self._emit(_instr(Op.LOCAL_SET, slot))
            self._emit(_instr(Op.GLOBAL_SET, name))
            return
        elif isinstance(node.target, MemberAccess):
            # struct.field = value -> LOCAL_GET + val + STRUCT_STORE field + LOCAL_SET
            if node.target.member == '_':
                # me1._ = MyUnionType -> ENUM_STORE
                if isinstance(node.target.object, Identifier):
                    var_name  = node.target.object.name
                    type_name = self._local_types.get(var_name)
                    if type_name and type_name in self._enum_names:
                        self._visit_expr(node.target.object)
                        self._visit_expr(node.value)
                        self._emit(_instr(Op.ENUM_STORE))
                        slot = self._alloc_local(var_name)
                        self._emit(_instr(Op.LOCAL_SET, slot))
                        return
                # Fallback: synthetic tag slot
                tag_slot_name = f'__{node.target.object.name if isinstance(node.target.object, Identifier) else "__"}__tag__'
                tag_slot = self._alloc_local(tag_slot_name)
                self._visit_expr(node.value)
                self._emit(_instr(Op.LOCAL_SET, tag_slot))
            elif isinstance(node.target.object, Identifier):
                var_name = node.target.object.name
                slot = self._alloc_local(var_name)
                self._visit_expr(node.target.object)  # push current struct
                self._visit_expr(node.value)
                self._emit(_instr(Op.STRUCT_STORE, node.target.member))
                self._emit(_instr(Op.LOCAL_SET, slot))  # write back
            else:
                # Complex lhs - fall back to STRUCT_LOAD chain
                self._visit_expr(node.target.object)
                self._visit_expr(node.value)
                self._emit(_instr(Op.STRUCT_STORE, node.target.member))
        elif isinstance(node.target, ArrayAccess):
            if not isinstance(node.target.array, Identifier):
                raise FVMCodegenError(
                    'fvmcodegen: array assignment target must be a simple identifier in comptime',
                    node
                )
            arr_name = node.target.array.name
            # Heap array: compute address and use typed STORE
            if arr_name in self._heap_vars:
                heap_info = self._heap_vars[arr_name]
                if len(heap_info) == 3:
                    elem_ttag, elem_bytes, _count = heap_info
                    self._emit(_instr(Op.LOCAL_GET, self._locals[arr_name]))
                    self._visit_expr(node.target.index)
                    if elem_bytes > 1:
                        self._emit(_instr(Op.PUSH, Val(TTag.UINT, elem_bytes)))
                        self._emit(_instr(Op.MUL))
                    self._emit(_instr(Op.ADD))
                    self._visit_expr(node.value)
                    self._emit(_instr(Op.STORE, elem_ttag, elem_bytes))
                    return
            arr_slot = self._alloc_local(arr_name)
            self._visit_expr(node.target.array)   # push array
            self._visit_expr(node.target.index)   # push index
            self._visit_expr(node.value)           # push value
            self._emit(_instr(Op.ARRAY_STORE))     # -> updated array
            self._emit(_instr(Op.LOCAL_SET, arr_slot))  # write back
        elif isinstance(node.target, PointerDeref):
            # *ptr = value  ->  push ptr, push value, LOCAL_DEREF_SET
            self._visit_expr(node.target.pointer)
            self._visit_expr(node.value)
            self._emit(_instr(Op.LOCAL_DEREF_SET))
        else:
            raise FVMCodegenError(
                f'fvmcodegen: unsupported assignment target in comptime: {type(node.target).__name__}',
                node
            )

    def _visit_compound_assign(self, node: CompoundAssignment):
        """Desugar compound assignment: x op= val  ->  x = x op val"""
        if not isinstance(node.target, Identifier):
            loc = f' [{node.source_line}:{node.source_col}]' if node.source_line else ''
            raise NotImplementedError(
                f'fvmcodegen: only simple identifier compound-assignment in comptime{loc}'
            )
        name = node.target.name
        slot = self._alloc_local(name)
        # Push LHS
        self._emit(_instr(Op.LOCAL_GET, slot))
        # Push RHS
        self._visit_expr(node.value)
        # Emit the base operator
        self._emit_binary_op_for_compound(node.op_token)
        # Store result
        self._emit(_instr(Op.LOCAL_SET, slot))

    def _emit_binary_op_for_compound(self, op_token):
        """Map a compound-assignment operator token to its base binary opcode."""
        from flexer import TokenType
        _map = {
            TokenType.PLUS_ASSIGN:            Op.ADD,
            TokenType.MINUS_ASSIGN:           Op.SUB,
            TokenType.MULTIPLY_ASSIGN:        Op.MUL,
            TokenType.DIVIDE_ASSIGN:          Op.DIV,
            TokenType.MODULO_ASSIGN:          Op.MOD,
            TokenType.POWER_ASSIGN:           Op.POW,
            TokenType.AND_ASSIGN:             Op.BAND,
            TokenType.OR_ASSIGN:              Op.BOR,
            TokenType.XOR_ASSIGN:             Op.BXOR,
            TokenType.BITAND_ASSIGN:          Op.BAND,
            TokenType.BITOR_ASSIGN:           Op.BOR,
            TokenType.BITXOR_ASSIGN:          Op.BXOR,
            TokenType.BITSHIFT_LEFT_ASSIGN:   Op.SHL,
            TokenType.BITSHIFT_RIGHT_ASSIGN:  Op.SHR,
        }
        oc = _map.get(op_token)
        if oc:
            self._emit(_instr(oc))
        else:
            raise NotImplementedError(
                f'fvmcodegen: compound assign op {op_token!r} not supported'
            )

    # ------------------------------------------------------------------
    # Expression statement
    # ------------------------------------------------------------------

    def _visit_expr_stmt(self, node: ExpressionStatement):
        pushes = self._visit_expr(node.expression)
        # Only pop if the expression left a value on the stack
        if pushes:
            self._emit(_instr(Op.POP))

    # ------------------------------------------------------------------
    # Expressions
    # ------------------------------------------------------------------

    def _visit_expr(self, node: ASTNode) -> bool:
        """
        Compile an expression.
        Returns True if a value was left on the VM stack, False if not
        (e.g. void compiler.io calls that consume args and push nothing).
        """
        t = type(node)
        if t is Literal:               return self._visit_literal(node)
        elif t is StringLiteral:       return self._visit_string_literal(node)
        elif t is FStringLiteral:      return self._visit_fstring_literal(node)
        elif t is ArrayLiteral:        return self._visit_array_literal(node)
        elif t is Identifier:          return self._visit_identifier(node)
        elif t is BinaryOp:            return self._visit_binary_op(node)
        elif t is UnaryOp:             return self._visit_unary_op(node)
        elif t is FunctionCall:        return self._visit_function_call(node)
        elif t is MethodCall:          return self._visit_method_call(node)
        elif t is ArrayAccess:         return self._visit_array_access(node)
        elif t is macroCall:           return self._visit_macro_call(node)
        elif t is TypeFuncCall:        return self._visit_type_func_call(node)
        elif t is StructFieldAccess:   return self._visit_struct_field_access(node)
        elif t is StructInstance:      return self._visit_struct_instance(node)
        elif t is StructLiteral:       return self._visit_struct_literal(node)
        elif t is StructRecast:        return self._visit_struct_recast(node)
        elif t is MemberAccess:        return self._visit_member_access(node)
        elif t is Assignment:          self._visit_assignment(node); return False
        elif t is CompoundAssignment:  self._visit_compound_assign(node); return False
        elif t is AddressOf:           return self._visit_address_of(node)
        elif t is PointerDeref:        return self._visit_pointer_deref(node)
        elif t is SizeOf:              return self._visit_sizeof(node)
        elif t is TypeOf:              return self._visit_typeof(node)
        elif t is InExpression:        return self._visit_in_expression(node)
        elif t is CastExpression:      return self._visit_cast(node)
        elif t is TypeConvertExpression: return self._visit_cast(node)
        elif t is InlineAsm:           return self._visit_inline_asm(node)
        else:
            raise FVMCodegenError(
                f'fvmcodegen: unsupported expression in comptime: {type(node).__name__}',
                node
            )

    def _visit_literal(self, node: Literal):
        dt = node.type
        ttag = _datatype_to_ttag(dt)
        raw = node.value
        if ttag in (TTag.INT, TTag.UINT, TTag.LONG, TTag.ULONG, TTag.BYTE, TTag.CHAR):
            if isinstance(raw, int):
                data = raw
            elif isinstance(raw, str) and len(raw) == 1:
                data = ord(raw)
            else:
                data = int(raw)
        elif ttag in (TTag.FLOAT, TTag.DOUBLE):
            data = float(raw) if not isinstance(raw, float) else raw
        elif ttag == TTag.BOOL:
            data = int(bool(raw))
        else:
            data = raw
        self._emit(_instr(Op.PUSH, Val(ttag, data)))
        return True

    def _visit_string_literal(self, node: StringLiteral):
        self._emit(_instr(Op.PUSH, Val(TTag.BYTES, node.value.encode('utf-8'))))
        return True

    def _visit_fstring_literal(self, node: FStringLiteral) -> bool:
        """
        f-string: each part is either a plain str or an Expression.
        Strategy: push each part as a BYTES value (converting expressions via
        INT_TO_STR), then STR_CAT them pairwise into a single string.
        An empty f-string pushes an empty BYTES value.
        """
        parts = node.parts
        if not parts:
            self._emit(_instr(Op.PUSH, Val(TTag.BYTES, b'')))
            return True

        # Strip f" prefix from first string part and closing " from last string part
        # when parse_f_string was called from primary_expression without pre-stripping.
        if parts and isinstance(parts[0], str) and parts[0].startswith('f"'):
            parts = list(parts)
            parts[0] = parts[0][2:]  # strip f"
        if parts and isinstance(parts[-1], str) and parts[-1].endswith('"'):
            parts = list(parts)
            parts[-1] = parts[-1][:-1]  # strip closing "

        def _emit_part(part):
            if isinstance(part, str):
                self._emit(_instr(Op.PUSH, Val(TTag.BYTES, part.encode('utf-8'))))
            else:
                self._visit_expr(part)
                self._emit(_instr(Op.INT_TO_STR))

        _emit_part(parts[0])
        for part in parts[1:]:
            _emit_part(part)
            self._emit(_instr(Op.STR_CAT))
        return True

    def _visit_array_literal(self, node: ArrayLiteral):
        """
        String literals (ArrayLiteral with is_string=True) are pushed as
        Val(TTag.BYTES, bytes).  _read_vm_string() in fvm.py accepts BYTES
        directly, so compiler.io.console.print and friends work without
        needing heap allocation at codegen time.
        """
        if node.is_string and node.string_value is not None:
            raw = node.string_value.encode('utf-8')
            self._emit(_instr(Op.PUSH, Val(TTag.BYTES, raw)))
            return True
        # Non-string array literal: allocate on VM heap at runtime
        elem_type = 'int'
        if node.element_type is not None:
            from ftypesys import DataType as _DT
            _dt_to_name = {
                _DT.INT: 'int', _DT.UINT: 'uint',
                _DT.LONG: 'long', _DT.ULONG: 'ulong',
                _DT.FLOAT: 'float', _DT.DOUBLE: 'double',
                _DT.BOOL: 'bool', _DT.BYTE: 'byte', _DT.CHAR: 'char',
            }
            elem_type = _dt_to_name.get(node.element_type.base_type, 'int')
        count = len(node.elements)
        self._emit(_instr(Op.ARRAY_NEW, elem_type, count))
        arr_slot = self._alloc_local('__arr_tmp__')
        self._emit(_instr(Op.LOCAL_SET, arr_slot))
        for idx, elem in enumerate(node.elements):
            self._emit(_instr(Op.LOCAL_GET, arr_slot))
            self._emit(_instr(Op.PUSH, Val(TTag.INT, idx)))
            self._visit_expr(elem)
            self._emit(_instr(Op.ARRAY_STORE))
            self._emit(_instr(Op.LOCAL_SET, arr_slot))
        self._emit(_instr(Op.LOCAL_GET, arr_slot))
        return True

    def _visit_identifier(self, node: Identifier):
        name = node.name
        if name in self._outer_globals:
            self._emit(_instr(Op.GLOBAL_GET, name))
            return True
        if name in self._locals:
            self._emit(_instr(Op.LOCAL_GET, self._locals[name]))
            if name in self._heap_vars:
                ttag, byte_size = self._heap_vars[name]
                self._emit(_instr(Op.LOAD, ttag, byte_size))
            return True
        # Try active using-namespaces: standard::datetime -> standard__datetime__name
        for ns in reversed(self._using_namespaces):
            qualified = f'{ns}__{name}'
            if qualified in self._locals:
                self._emit(_instr(Op.LOCAL_GET, self._locals[qualified]))
                return True
        # Type name used as a value (e.g. union/struct type in tagged union assignment)
        if name in self._struct_layouts:
            self._emit(_instr(Op.PUSH, Val(TTag.BYTES, name.encode('utf-8'))))
            return True
        # Block-global variable defined in this comptime block (e.g. via namespace global)
        if name in self._block_globals:
            self._emit(_instr(Op.GLOBAL_GET, name))
            return True
        loc = f' [{node.source_line}:{node.source_col}]' if node.source_line else ''
        raise NameError(f'fvmcodegen: undefined comptime variable {name!r}{loc}')

    def _visit_binary_op(self, node: BinaryOp):
        op = node.operator
        # Short-circuit logical operators as branching sequences
        if op == Operator.AND:
            self._visit_expr(node.left)
            self._emit(_instr(Op.DUP))
            jnf_idx = self._emit(_instr(Op.JNF, 0))
            self._emit(_instr(Op.POP))
            self._visit_expr(node.right)
            self._patch_at(jnf_idx, Op.JNF, self._current_ip())
            return True
        if op == Operator.OR:
            self._visit_expr(node.left)
            self._emit(_instr(Op.DUP))
            jif_idx = self._emit(_instr(Op.JIF, 0))
            self._emit(_instr(Op.POP))
            self._visit_expr(node.right)
            self._patch_at(jif_idx, Op.JIF, self._current_ip())
            return True
        self._visit_expr(node.left)
        self._visit_expr(node.right)
        # Single-opcode operators
        _op_map = {
            Operator.ADD:            Op.ADD,
            Operator.SUB:            Op.SUB,
            Operator.MUL:            Op.MUL,
            Operator.DIV:            Op.DIV,
            Operator.MOD:            Op.MOD,
            Operator.POWER:          Op.POW,
            Operator.XOR:            Op.BXOR,
            Operator.BITAND:         Op.BAND,
            Operator.BITOR:          Op.BOR,
            Operator.BITXOR:         Op.BXOR,
            Operator.BITSHIFT_LEFT:  Op.SHL,
            Operator.BITSHIFT_RIGHT: Op.SHR,
            Operator.EQUAL:          Op.CMP_EQ,
            Operator.NOT_EQUAL:      Op.CMP_NE,
            Operator.LESS_THAN:      Op.CMP_LT,
            Operator.LESS_EQUAL:     Op.CMP_LE,
            Operator.GREATER_THAN:   Op.CMP_GT,
            Operator.GREATER_EQUAL:  Op.CMP_GE,
        }
        vm_op = _op_map.get(op)
        if vm_op is not None:
            self._emit(_instr(vm_op))
            return True
        # Composite operators: base op + BNOT
        _composite_map = {
            Operator.NAND:     Op.BAND,   # !(a & b)
            Operator.NOR:      Op.BOR,    # !(a | b)
            Operator.BITNAND:  Op.BAND,   # ~(a `& b)
            Operator.BITNOR:   Op.BOR,    # ~(a `| b)
            Operator.BITXNOT:  Op.BXOR,   # ~(a `^^ b)
            Operator.BITXNAND: Op.BAND,   # ~(xor(a,b) & ...)
            Operator.BITXNOR:  Op.BOR,    # ~(xor(a,b) | ...)
        }
        base_op = _composite_map.get(op)
        if base_op is not None:
            self._emit(_instr(base_op))
            self._emit(_instr(Op.BNOT))
            return True
        loc = f' [{node.source_line}:{node.source_col}]' if node.source_line else ''
        raise NotImplementedError(
            f'fvmcodegen: binary operator {op!r} not supported in comptime{loc}'
        )

    def _visit_unary_op(self, node: UnaryOp):
        op = node.operator
        if op in (Operator.INCREMENT, Operator.DECREMENT):
            if isinstance(node.operand, MemberAccess) and isinstance(node.operand.object, Identifier):
                # struct.field++ / struct.field-- on a simple identifier receiver
                var_name = node.operand.object.name
                field    = node.operand.member
                slot     = self._alloc_local(var_name)
                delta    = Val(TTag.INT, 1)
                arith    = Op.ADD if op == Operator.INCREMENT else Op.SUB
                if node.is_postfix:
                    # push old value for expression result
                    self._emit(_instr(Op.LOCAL_GET, slot))
                    self._emit(_instr(Op.STRUCT_LOAD, field))
                # compute new value
                self._emit(_instr(Op.LOCAL_GET, slot))
                self._emit(_instr(Op.STRUCT_LOAD, field))
                self._emit(_instr(Op.PUSH, delta))
                self._emit(_instr(arith))
                if not node.is_postfix:
                    self._emit(_instr(Op.DUP))
                # store new value back into the struct
                self._emit(_instr(Op.LOCAL_GET, slot))
                self._emit(_instr(Op.SWAP))  # stack: struct, new_val
                self._emit(_instr(Op.STRUCT_STORE, field))
                self._emit(_instr(Op.LOCAL_SET, slot))
                if var_name in self._block_globals:
                    self._emit(_instr(Op.GLOBAL_SET, var_name))
                return True
            if not isinstance(node.operand, Identifier):
                loc = f' [{node.source_line}:{node.source_col}]' if node.source_line else ''
                raise NotImplementedError(
                    f'fvmcodegen: ++/-- only on simple identifiers in comptime{loc}'
                )
            name = node.operand.name
            if name in self._outer_globals:
                self._emit(_instr(Op.GLOBAL_GET, name))
                self._emit(_instr(Op.PUSH, Val(TTag.INT, 1)))
                self._emit(_instr(Op.ADD if op == Operator.INCREMENT else Op.SUB))
                self._emit(_instr(Op.DUP))
                self._emit(_instr(Op.GLOBAL_SET, name))
                return True
            slot = self._alloc_local(name)
            if node.is_postfix:
                self._emit(_instr(Op.LOCAL_GET, slot))
                self._emit(_instr(Op.LOCAL_GET, slot))
                self._emit(_instr(Op.PUSH, Val(TTag.INT, 1)))
                self._emit(_instr(Op.ADD if op == Operator.INCREMENT else Op.SUB))
                if name in self._block_globals:
                    self._emit(_instr(Op.DUP))
                self._emit(_instr(Op.LOCAL_SET, slot))
                if name in self._block_globals:
                    self._emit(_instr(Op.GLOBAL_SET, name))
            else:
                self._emit(_instr(Op.LOCAL_GET, slot))
                self._emit(_instr(Op.PUSH, Val(TTag.INT, 1)))
                self._emit(_instr(Op.ADD if op == Operator.INCREMENT else Op.SUB))
                self._emit(_instr(Op.DUP))
                self._emit(_instr(Op.LOCAL_SET, slot))
                if name in self._block_globals:
                    self._emit(_instr(Op.GLOBAL_SET, name))
            return True
        self._visit_expr(node.operand)
        _op_map = {
            Operator.SUB:    Op.NEG,
            Operator.NOT:    Op.NOT,
            Operator.BITNOT: Op.BNOT,
            Operator.BITXNOT: Op.BNOT,
        }
        vm_op = _op_map.get(op)
        if vm_op is None:
            loc = f' [{node.source_line}:{node.source_col}]' if node.source_line else ''
            raise NotImplementedError(
                f'fvmcodegen: unary operator {op!r} not supported in comptime{loc}'
            )
        self._emit(_instr(vm_op))
        return True

    def _visit_type_func_call(self, node: TypeFuncCall) -> bool:
        """
        Emit a call to a comptime type function.
        Push receiver first (becomes '_' / slot 0), then explicit args, then CALL.
        """
        self._visit_expr(node.receiver)
        for arg in node.arguments:
            self._visit_expr(arg)
        mangled = TypeFuncDef.mangle(node.type_name, node.func_name)
        self._emit(_instr(Op.CALL, mangled, 1 + len(node.arguments)))
        return True

    def _visit_sizeof(self, node: SizeOf) -> bool:
        """
        sizeof(T) returns the bit width of T as a ulong.
        Supports TypeSystem targets and Identifier targets (type aliases, locals).
        """
        from ftypesys import TypeSystem as _TS, DataType as _DT
        _prim_bits = {
            _DT.SINT:  32, _DT.UINT:  32,
            _DT.SLONG: 64, _DT.ULONG: 64,
            _DT.FLOAT: 32, _DT.DOUBLE: 64,
            _DT.BOOL:  1,  _DT.BYTE:  8,
            _DT.CHAR:  8,  _DT.DATA:  0,
        }
        bits = None
        target = node.target

        if isinstance(target, _TS):
            if target.base_type == _DT.DATA and target.bit_width:
                bits = target.bit_width
            elif target.is_pointer:
                bits = 64
            elif target.base_type in _prim_bits:
                bits = _prim_bits[target.base_type]

        elif isinstance(target, Identifier):
            # Check heap vars first — they carry full type info
            if target.name in self._heap_vars:
                heap_info = self._heap_vars[target.name]
                if len(heap_info) == 3:  # array: (elem_ttag, elem_bytes, count)
                    elem_ttag, elem_bytes, count = heap_info
                    bits = elem_bytes * 8 * count
                else:  # scalar: (ttag, byte_size)
                    bits = heap_info[1] * 8
            # Check full typespec (has array dims etc.)
            if bits is None and target.name in self._local_typespecs:
                bits = self._type_bit_width(self._local_typespecs[target.name])
            if bits is None:
                type_name = self._local_types.get(target.name)
                if type_name is not None:
                    if type_name.startswith('__data_'):
                        bits = int(type_name[7:])
                    else:
                        _name_bits = {
                            'int': 32, 'uint': 32, 'long': 64, 'ulong': 64,
                            'float': 32, 'double': 64, 'bool': 1,
                            'byte': 8, 'char': 8,
                        }
                        bits = _name_bits.get(type_name)
            # Check struct layouts
            if bits is None:
                layout = self._struct_layouts.get(target.name)
                if layout is not None:
                    bits = layout.total_bits if layout.total_bits else layout.total_size * 8

        if bits is None:
            bits = 0  # unknown — emit 0 rather than crash

        self._emit(_instr(Op.PUSH, Val(TTag.ULONG, bits)))
        return True

    def _visit_typeof(self, node: TypeOf) -> bool:
        """
        typeof(expr) returns an integer kind constant matching the TypeOf.KIND_* values.
        typeof(bool), typeof(int), etc. resolve the bare type name.
        typeof(var) resolves from the variable's recorded local type.
        """
        from ftypesys import DataType as _DT
        # KIND constants mirror fast.TypeOf
        _KIND = {
            'int':    1,  'uint':   2,  'float':  3,  'double': 4,
            'bool':   5,  'char':   6,  'byte':   7,
            'long':   8,  'ulong':  9,
        }
        _DT_KIND = {
            _DT.SINT:   1, _DT.UINT:   2, _DT.FLOAT:  3, _DT.DOUBLE: 4,
            _DT.BOOL:   5, _DT.CHAR:   6, _DT.BYTE:   7,
            _DT.SLONG:  8, _DT.ULONG:  9,
            _DT.STRUCT: 12, _DT.OBJECT: 13, _DT.VOID: 14,
        }
        kind = 0  # KIND_UNKNOWN
        expr = node.expression

        if isinstance(expr, Identifier):
            name = expr.name
            # Bare type keyword used as typeof argument (e.g. typeof(bool))
            if name in _KIND:
                kind = _KIND[name]
            # Known struct type
            elif name in self._struct_layouts:
                kind = 12  # KIND_STRUCT
            # Variable whose type was recorded
            else:
                type_name = self._local_types.get(name)
                if type_name is not None:
                    kind = _KIND.get(type_name, 0)
                    if kind == 0 and type_name in self._struct_layouts:
                        kind = 12  # KIND_STRUCT
        else:
            # For a TypeSystem target (e.g. typeof(bool) parsed as TS)
            from ftypesys import TypeSystem as _TS
            if isinstance(expr, _TS):
                kind = _DT_KIND.get(expr.base_type, 0)

        self._emit(_instr(Op.PUSH, Val(TTag.INT, kind)))
        return True

    def _visit_in_expression(self, node: InExpression) -> bool:
        """
        needle in haystack — linear scan of the array for needle.
        Strategy: evaluate needle and haystack once, then emit a counted
        loop that INDEX_GETs each element, CMP_EQs with needle, and BORs
        the result into an accumulator.  Leaves a BOOL on the stack.

        Since we don't know the array length at codegen time, we use the
        VM's ARRAY_LEN op if available, otherwise we emit a runtime loop
        using the meta count stored in the PTR.  For simplicity we use a
        pure bytecode loop with a runtime length read.
        """
        # Evaluate needle into a temp slot
        self._visit_expr(node.needle)
        needle_slot = self._alloc_local('__in_needle__')
        self._emit(_instr(Op.LOCAL_SET, needle_slot))

        # Evaluate haystack (array PTR) into a temp slot
        self._visit_expr(node.haystack)
        arr_slot = self._alloc_local('__in_arr__')
        self._emit(_instr(Op.LOCAL_SET, arr_slot))

        # Get array length via STR_LEN workaround — use ARRAY_LEN if it exists,
        # otherwise push the count from meta via a dedicated op.
        # Since the VM doesn't have ARRAY_LEN, we use a Python-level count stored
        # as an inline literal by pushing the array PTR and reading meta at runtime.
        # We emit a loop with a runtime index counter using JMP/JNF.

        # result accumulator = false
        result_slot = self._alloc_local('__in_result__')
        self._emit(_instr(Op.PUSH, Val(TTag.BOOL, 0)))
        self._emit(_instr(Op.LOCAL_SET, result_slot))

        # index counter = 0
        idx_slot = self._alloc_local('__in_idx__')
        self._emit(_instr(Op.PUSH, Val(TTag.INT, 0)))
        self._emit(_instr(Op.LOCAL_SET, idx_slot))

        # Get array length: push arr PTR, emit ARRAY_LEN op
        len_slot = self._alloc_local('__in_len__')
        self._emit(_instr(Op.LOCAL_GET, arr_slot))
        self._emit(_instr(Op.ARRAY_LEN))
        self._emit(_instr(Op.LOCAL_SET, len_slot))

        # Loop start: if idx >= len, jump out
        loop_start = self._current_ip()
        self._emit(_instr(Op.LOCAL_GET, idx_slot))
        self._emit(_instr(Op.LOCAL_GET, len_slot))
        self._emit(_instr(Op.CMP_GE))
        exit_patch = self._emit(_instr(Op.JIF, 0))

        # elem = arr[idx]
        self._emit(_instr(Op.LOCAL_GET, arr_slot))
        self._emit(_instr(Op.LOCAL_GET, idx_slot))
        self._emit(_instr(Op.ARRAY_LOAD))

        # result |= (elem == needle)
        self._emit(_instr(Op.LOCAL_GET, needle_slot))
        self._emit(_instr(Op.CMP_EQ))
        self._emit(_instr(Op.LOCAL_GET, result_slot))
        self._emit(_instr(Op.BOR))
        self._emit(_instr(Op.LOCAL_SET, result_slot))

        # idx += 1
        self._emit(_instr(Op.LOCAL_GET, idx_slot))
        self._emit(_instr(Op.PUSH, Val(TTag.INT, 1)))
        self._emit(_instr(Op.ADD))
        self._emit(_instr(Op.LOCAL_SET, idx_slot))

        # jump back to loop start
        self._emit(_instr(Op.JMP, loop_start))

        # patch exit
        self._patch_at(exit_patch, Op.JIF, self._current_ip())

        self._emit(_instr(Op.LOCAL_GET, result_slot))
        return True

    def _visit_pointer_deref(self, node: PointerDeref) -> bool:
        """
        *ptr -- dereference a VM stack pointer.
        PTR(slot) -> locals[slot] for regular pointers.
        For function pointers, *pb returns the slot index itself (the address of the function).
        """
        from fast import Identifier as _Id
        if (isinstance(node.pointer, _Id) and
                self._local_types.get(node.pointer.name) == '__funcptr__'):
            # *pb on a funcptr: pb holds PTR(slot); return slot index as ULONG
            slot = self._locals[node.pointer.name]
            self._emit(_instr(Op.LOCAL_GET, slot))
            self._emit(_instr(Op.CAST, TTag.ULONG))
            return True
        self._visit_expr(node.pointer)
        self._emit(_instr(Op.LOCAL_DEREF))
        return True

    def _visit_address_of(self, node: AddressOf) -> bool:
        """
        @x — push Val(TTag.PTR, slot_index).
        For variables: slot holds the variable value.
        For functions: allocate a slot holding Val(BYTES, func_name), push PTR to it.
        @arr[idx] — evaluate arr[idx], store result in a temp slot, push PTR to that slot.
        """
        if isinstance(node.expression, ArrayAccess):
            # Evaluate the subscript expression to get the element value, then
            # store it in a fresh temp slot and return a PTR to that slot.
            # This supports patterns like @days[dow][0] -> byte* used as ds[i].
            tmp_name = self._fresh_tmp()
            tmp_slot = self._alloc_local(tmp_name)
            self._visit_expr(node.expression)      # push element value
            self._emit(_instr(Op.LOCAL_SET, tmp_slot))  # store into temp slot
            self._emit(_instr(Op.PUSH, Val(TTag.PTR, tmp_slot)))
            return True
        if not isinstance(node.expression, Identifier):
            raise FVMCodegenError(
                'fvmcodegen: address-of only supported on simple identifiers in comptime',
                node
            )
        name = node.expression.name
        # Variable address
        if name in self._locals:
            slot = self._locals[name]
            self._emit(_instr(Op.PUSH, Val(TTag.PTR, slot)))
            return True
        # Function address: allocate a slot for the function name value
        fn_slot_name = f'__fnaddr_{name}__'
        slot = self._alloc_local(fn_slot_name)
        # Store the function name as BYTES in that slot
        self._emit(_instr(Op.PUSH, Val(TTag.BYTES, name.encode('utf-8'))))
        self._emit(_instr(Op.LOCAL_SET, slot))
        # Push PTR to that slot
        self._emit(_instr(Op.PUSH, Val(TTag.PTR, slot)))
        return True

    def _visit_inline_asm(self, node: InlineAsm) -> bool:
        """
        Emit an INLINE_ASM instruction for an inline asm block.
        Parses constraints to determine input/output operands and pushes
        input values onto the stack before the instruction.
        """
        import re as _re

        constraints = node.constraints or ''

        # Split constraints into outputs:inputs:clobbers
        parts = constraints.split(':')
        outputs_str = parts[0].strip() if len(parts) > 0 else ''
        inputs_str  = parts[1].strip() if len(parts) > 1 else ''

        # Parse output operands: "=r"(varname)
        output_names = []
        if outputs_str:
            for m in _re.finditer(r'"=r"\((\w+)\)', outputs_str):
                output_names.append(m.group(1))

        # Parse input operands: "r"(varname)
        input_names = []
        if inputs_str:
            for m in _re.finditer(r'"r"\((\w+)\)', inputs_str):
                input_names.append(m.group(1))

        n_outputs = len(output_names)
        n_inputs  = len(input_names)

        # Push input values onto the stack
        for name in input_names:
            if name in self._locals:
                self._emit(_instr(Op.LOCAL_GET, self._locals[name]))
            elif name in self._outer_globals or name in self._block_globals:
                self._emit(_instr(Op.GLOBAL_GET, name))
            else:
                self._emit(_instr(Op.PUSH, Val(TTag.LONG, 0)))

        self._emit(_instr(Op.INLINE_ASM, node.body, constraints, n_inputs, n_outputs, output_names))

        # If there are outputs, the op pushes a value
        return n_outputs > 0

    def _visit_cast(self, node) -> bool:
        """
        Type cast / type conversion expression: ulong(x), int(y), float(z), etc.
        Evaluates the inner expression then emits a CAST opcode to coerce the
        top-of-stack value to the target TTag.
        """
        self._visit_expr(node.expression)
        from ftypesys import DataType as _DT
        _dt_to_ttag = {
            _DT.SINT:   TTag.INT,
            _DT.UINT:   TTag.UINT,
            _DT.SLONG:  TTag.LONG,
            _DT.ULONG:  TTag.ULONG,
            _DT.FLOAT:  TTag.FLOAT,
            _DT.DOUBLE: TTag.DOUBLE,
            _DT.BOOL:   TTag.BOOL,
            _DT.BYTE:   TTag.BYTE,
            _DT.CHAR:   TTag.CHAR,
        }
        ts = node.target_type
        if ts.base_type is not None and ts.base_type in _dt_to_ttag:
            target_ttag = _dt_to_ttag[ts.base_type]
        else:
            # Pointer cast or unknown — treat as PTR
            target_ttag = TTag.PTR
        self._emit(_instr(Op.CAST, target_ttag))
        return True

    def _flatten_dotted_name(self, node) -> Optional[str]:
        """
        Flatten a chain of MethodCall / MemberAccess / Identifier nodes into a
        dot-separated name string, e.g. 'compiler.io.console.print'.
        Returns None if the chain contains non-name nodes.
        """
        if isinstance(node, Identifier):
            return node.name
        if isinstance(node, MemberAccess):
            base = self._flatten_dotted_name(node.object)
            return f'{base}.{node.member}' if base is not None else None
        if isinstance(node, MethodCall):
            base = self._flatten_dotted_name(node.object)
            return f'{base}.{node.method_name}' if base is not None else None
        return None

    def _visit_function_call(self, node: FunctionCall):
        _COMPILER_IO = {
            'compiler__io__console__print':  Op.COMPILER_PRINT,
            'compiler.io.console.print':     Op.COMPILER_PRINT,
            'compiler__io__console__input':  Op.COMPILER_INPUT,
            'compiler.io.console.input':     Op.COMPILER_INPUT,
            'compiler__io__readfile':        Op.COMPILER_READFILE,
            'compiler.io.readfile':          Op.COMPILER_READFILE,
            'compiler__io__writefile':       Op.COMPILER_WRITEFILE,
            'compiler.io.writefile':         Op.COMPILER_WRITEFILE,
            'compiler.fvm.dump':             Op.COMPILER_FVM_DUMP,
            'compiler__fvm__dump':           Op.COMPILER_FVM_DUMP,
            'compiler.fvm.loadlib':          Op.COMPILER_LOADLIB,
            'compiler__fvm__loadlib':        Op.COMPILER_LOADLIB,
            'compiler.import.stdlib':        Op.COMPILER_IMPORT_STDLIB,
            'compiler__import__stdlib':      Op.COMPILER_IMPORT_STDLIB,
            'compiler.import.local':         Op.COMPILER_IMPORT_LOCAL,
            'compiler__import__local':       Op.COMPILER_IMPORT_LOCAL,
            'compiler.fpm.package':          Op.COMPILER_FPM_PACKAGE,
            'compiler__fpm__package':        Op.COMPILER_FPM_PACKAGE,
        }
        # Opcodes that push a return value onto the stack
        _PUSHES = {Op.COMPILER_INPUT, Op.COMPILER_READFILE}
        name = node.name
        opcode = _COMPILER_IO.get(name)
        if opcode is not None:
            if opcode != Op.COMPILER_INPUT:
                for arg in node.arguments:
                    self._visit_expr(arg)
            self._emit(_instr(opcode))
            return opcode in _PUSHES
        # Function pointer call: pb() where pb is a local __funcptr__ slot
        if (name in self._locals and
                self._local_types.get(name) == '__funcptr__'):
            for arg in node.arguments:
                self._visit_expr(arg)
            # pb holds PTR(fn_slot); fn_slot holds BYTES(func_name)
            # LOCAL_GET pb -> PTR(fn_slot); LOCAL_DEREF -> BYTES(func_name)
            self._emit(_instr(Op.LOCAL_GET, self._locals[name]))
            self._emit(_instr(Op.LOCAL_DEREF))
            self._emit(_instr(Op.CALL_PTR, len(node.arguments)))
            return True
        # Try active using-namespaces for unqualified function names.
        # If known at codegen time, use the qualified name directly.
        # Otherwise keep the bare name -- the VM suffix-match (__name)
        # will find it at runtime after imports have registered functions.
        resolved_name = name
        for ns in reversed(self._using_namespaces):
            qualified = f'{ns}__{name}'
            if (qualified in self.compiled_functions or
                    qualified in self._known_functions):
                resolved_name = qualified
                break
        for arg in node.arguments:
            if isinstance(arg, Identifier) and arg.name in self._local_vars:
                raise FVMCodegenError(
                    f"fvmcodegen: local variable '{arg.name}' cannot escape scope (passed to function)",
                    arg)
            self._visit_expr(arg)
        if self._tail_call_self is not None and resolved_name == self._tail_call_self:
            self._emit(_instr(Op.TAIL_SELF, len(node.arguments)))
        else:
            self._emit(_instr(Op.CALL, resolved_name, len(node.arguments)))
        return True  # CALL/TAIL_SELF always pushes or loops

    def _visit_method_call(self, node: MethodCall):
        """
        Handle chained namespace/method calls inside comptime blocks.
        Flattens the receiver chain into a dotted name and maps compiler.io.*
        to dedicated VM opcodes; falls back to a generic CALL for others.
        """
        _COMPILER_IO_OPCODES = {
            'compiler.io.console.print':  Op.COMPILER_PRINT,
            'compiler.io.console.input':  Op.COMPILER_INPUT,
            'compiler.io.readfile':       Op.COMPILER_READFILE,
            'compiler.io.writefile':      Op.COMPILER_WRITEFILE,
            'compiler.fvm.dump':          Op.COMPILER_FVM_DUMP,
            'compiler.import.stdlib':     Op.COMPILER_IMPORT_STDLIB,
            'compiler.import.local':      Op.COMPILER_IMPORT_LOCAL,
            'compiler.fpm.package':       Op.COMPILER_FPM_PACKAGE,
            'compiler.fvm.loadlib':        Op.COMPILER_LOADLIB,
        }
        _PUSHES = {Op.COMPILER_INPUT, Op.COMPILER_READFILE}

        full_name = self._flatten_dotted_name(node)

        if full_name in _COMPILER_IO_OPCODES:
            opcode = _COMPILER_IO_OPCODES[full_name]
            if opcode != Op.COMPILER_INPUT:
                for arg in node.arguments:
                    self._visit_expr(arg)
            self._emit(_instr(opcode))
            return opcode in _PUSHES

        if full_name is not None:
            # Check if this is a type function call: receiver_var.method_name(args)
            # The receiver is a local variable; look up its declared type name and
            # try the __typefunc__<type_name>__<method_name> mangled key.
            if (isinstance(node.object, Identifier) and
                    node.object.name in self._local_types):
                type_name = self._local_types[node.object.name]
                from fast import TypeFuncDef as _TFD
                mangled = _TFD.mangle(type_name, node.method_name)
                if mangled in self.compiled_functions or mangled in self._known_functions:
                    # Push receiver as first arg (_), then explicit args
                    self._visit_expr(node.object)
                    for arg in node.arguments:
                        self._visit_expr(arg)
                    self._emit(_instr(Op.CALL, mangled, 1 + len(node.arguments)))
                    return True

            for arg in node.arguments:
                self._visit_expr(arg)
            self._emit(_instr(Op.CALL, full_name, len(node.arguments)))
            return True

        loc = f' [{node.source_line}:{node.source_col}]' if node.source_line else ''
        raise NotImplementedError(
            f'fvmcodegen: method call on complex receiver not supported in comptime: {node!r}{loc}'
        )

    def _visit_macro_call(self, node) -> bool:
        """
        Expand an expression macro call inline, mirroring CodegenVisitor.visit_macroCall.
        Looks up the macroDef, substitutes arguments, and visits the expanded body.
        """
        import copy
        macro_def = self._macro_table.get(node.name)
        if macro_def is None:
            raise FVMCodegenError(
                f"fvmcodegen: unknown expression macro '{node.name}'", node)
        if len(node.arguments) != len(macro_def.params):
            raise FVMCodegenError(
                f"fvmcodegen: macro '{node.name}' expects {len(macro_def.params)} "
                f"argument(s), got {len(node.arguments)}", node)
        subst = {param: copy.deepcopy(arg)
                 for param, arg in zip(macro_def.params, node.arguments)}
        body_copy = copy.deepcopy(macro_def.body)
        expanded = self._macro_substitute(body_copy, subst)
        return self._visit_expr(expanded)

    @staticmethod
    def _macro_substitute(node, subst: dict):
        """Recursively substitute macro parameters in an AST subtree."""
        import copy
        if isinstance(node, Identifier):
            if node.name in subst:
                return copy.deepcopy(subst[node.name])
            return node
        if isinstance(node, BinaryOp):
            node.left  = FVMCodegen._macro_substitute(node.left,  subst)
            node.right = FVMCodegen._macro_substitute(node.right, subst)
            return node
        if isinstance(node, UnaryOp):
            node.operand = FVMCodegen._macro_substitute(node.operand, subst)
            return node
        if isinstance(node, macroCall):
            node.arguments = [FVMCodegen._macro_substitute(a, subst) for a in node.arguments]
            return node
        if isinstance(node, FunctionCall):
            node.arguments = [FVMCodegen._macro_substitute(a, subst) for a in node.arguments]
            return node
        if isinstance(node, ArrayAccess):
            node.array = FVMCodegen._macro_substitute(node.array, subst)
            node.index = FVMCodegen._macro_substitute(node.index, subst)
            return node
        if isinstance(node, MemberAccess):
            node.object = FVMCodegen._macro_substitute(node.object, subst)
            return node
        if isinstance(node, AddressOf):
            node.expression = FVMCodegen._macro_substitute(node.expression, subst)
            return node
        if isinstance(node, PointerDeref):
            node.pointer = FVMCodegen._macro_substitute(node.pointer, subst)
            return node
        return node

    def _visit_array_access(self, node):
        # Check if array is a heap-allocated var — use typed LOAD instead of ARRAY_LOAD
        if isinstance(node.array, Identifier) and node.array.name in self._heap_vars:
            heap_info = self._heap_vars[node.array.name]
            if len(heap_info) == 3:  # (elem_ttag, elem_bytes, count) — array
                elem_ttag, elem_bytes, _count = heap_info
                # ptr + index * elem_bytes -> LOAD elem_ttag elem_bytes
                self._emit(_instr(Op.LOCAL_GET, self._locals[node.array.name]))
                self._visit_expr(node.index)
                if elem_bytes > 1:
                    self._emit(_instr(Op.PUSH, Val(TTag.UINT, elem_bytes)))
                    self._emit(_instr(Op.MUL))
                self._emit(_instr(Op.ADD))
                self._emit(_instr(Op.LOAD, elem_ttag, elem_bytes))
                return True
        # Check if array is a pointer to a known struct type (e.g. BlockEntry*)
        # Mirror LLVM GEP: offset = index * sizeof(struct), then load struct-sized bytes
        if isinstance(node.array, Identifier):
            _arr_name = node.array.name
            _type_name = self._local_types.get(_arr_name) or self._local_typespecs.get(_arr_name)
            if isinstance(_type_name, str) and _type_name in self._struct_layouts:
                _layout = self._struct_layouts[_type_name]
                _struct_size = _layout.total_size
                self._visit_expr(node.array)
                self._visit_expr(node.index)
                self._emit(_instr(Op.PUSH, Val(TTag.UINT, _struct_size)))
                self._emit(_instr(Op.MUL))
                self._emit(_instr(Op.ADD))
                self._emit(_instr(Op.LOAD, TTag.STRUCT, _struct_size, _type_name))
                return True
        self._visit_expr(node.array)
        self._visit_expr(node.index)
        self._emit(_instr(Op.ARRAY_LOAD))
        return True

    # ------------------------------------------------------------------
    # Control flow
    # ------------------------------------------------------------------

    def _visit_if(self, node: IfStatement):
        end_patches = []

        # Main if
        self._visit_expr(node.condition)
        jnf_idx = self._emit(_instr(Op.JNF, 0))
        self._visit_body(
            node.then_block.statements if isinstance(node.then_block, Block)
            else [node.then_block]
        )
        end_patches.append(self._emit(_instr(Op.JMP, 0)))
        self._patch_at(jnf_idx, Op.JNF, self._current_ip())

        # elif chains
        for cond, blk in (node.elif_blocks or []):
            self._visit_expr(cond)
            jnf_idx = self._emit(_instr(Op.JNF, 0))
            self._visit_body(blk.statements if isinstance(blk, Block) else [blk])
            end_patches.append(self._emit(_instr(Op.JMP, 0)))
            self._patch_at(jnf_idx, Op.JNF, self._current_ip())

        # else block
        if node.else_block is not None:
            self._visit_body(
                node.else_block.statements if isinstance(node.else_block, Block)
                else [node.else_block]
            )

        end_ip = self._current_ip()
        for idx in end_patches:
            self._patch_at(idx, Op.JMP, end_ip)

    def _emit_unpack(self, group: list, src_expr):
        """
        Unpack a scalar source into multiple variables.
        group[0] is the first (highest-bits) variable, group[-1] the last (lowest-bits).
        Element bit width is inferred from the target element type.
        """
        elem_dt = group[0].type_spec.base_type
        elem_ttag = _datatype_to_ttag(elem_dt)
        _bits = {
            DataType.SINT: 32, DataType.UINT: 32,
            DataType.SLONG: 64, DataType.ULONG: 64,
            DataType.BYTE: 8, DataType.CHAR: 8, DataType.BOOL: 1,
        }
        elem_bits = _bits.get(elem_dt, 32)
        n = len(group)
        # Build a mask for elem_bits
        mask = (1 << elem_bits) - 1

        # Evaluate and store the source once
        self._visit_expr(src_expr)
        src_slot = self._alloc_local('__unpack_src__')
        self._emit(_instr(Op.LOCAL_SET, src_slot))

        for i, decl in enumerate(group):
            slot = self._alloc_local(decl.name)
            # group[0] = MSB side: shift = (n-1-i)*elem_bits
            shift = (n - 1 - i) * elem_bits
            self._emit(_instr(Op.LOCAL_GET, src_slot))
            if shift > 0:
                self._emit(_instr(Op.PUSH, Val(TTag.INT, shift)))
                self._emit(_instr(Op.SHR))
            self._emit(_instr(Op.PUSH, Val(TTag.LONG, mask)))
            self._emit(_instr(Op.BAND))
            self._emit(_instr(Op.CAST, elem_ttag))
            self._emit(_instr(Op.LOCAL_SET, slot))
            # Record type
            if decl.type_spec is not None and decl.type_spec.base_type is not None:
                bt = decl.type_spec.base_type
                self._local_types[decl.name] = bt.value if hasattr(bt, 'value') else str(bt)

    def _emit_pack(self, arr: 'ArrayLiteral', target_type_spec):
        """
        Pack an ArrayLiteral into a scalar integer value.
        Elements are packed from LSB to MSB; the bit width of each element is
        inferred from the element type on the ArrayLiteral, defaulting to 32 bits
        (int-sized) per element.  The result is left on the stack as the target type.
        """
        target_ttag = _datatype_to_ttag(
            target_type_spec.base_type if target_type_spec else DataType.SLONG
        )
        # Determine per-element bit width from element_type or default to 32
        elem_bits = 32
        if arr.element_type is not None and arr.element_type.base_type is not None:
            _eb = {
                DataType.SINT: 32, DataType.UINT: 32,
                DataType.SLONG: 64, DataType.ULONG: 64,
                DataType.BYTE: 8,  DataType.CHAR: 8,
                DataType.BOOL: 1,
            }
            elem_bits = _eb.get(arr.element_type.base_type, 32)

        # Total bit width of the target type
        _total_bits = {
            DataType.SINT: 32, DataType.UINT: 32,
            DataType.SLONG: 64, DataType.ULONG: 64,
            DataType.BYTE: 8, DataType.CHAR: 8,
        }
        total_bits = _total_bits.get(
            target_type_spec.base_type if target_type_spec else DataType.SLONG, 64
        )
        n = len(arr.elements)
        if n == 0:
            self._emit(_instr(Op.PUSH, Val(target_ttag, 0)))
            return

        # Evaluate first element as the accumulator; it occupies the HIGH bits.
        # Element i shifts left by (n - 1 - i) * elem_bits.
        self._visit_expr(arr.elements[0])
        shift0 = (n - 1) * elem_bits
        if shift0 > 0:
            self._emit(_instr(Op.PUSH, Val(TTag.INT, shift0)))
            self._emit(_instr(Op.SHL))
        acc_slot = self._alloc_local('__pack_acc__')
        self._emit(_instr(Op.LOCAL_SET, acc_slot))

        for i, elem in enumerate(arr.elements[1:], start=1):
            shift = (n - 1 - i) * elem_bits
            self._visit_expr(elem)
            if shift > 0:
                self._emit(_instr(Op.PUSH, Val(TTag.INT, shift)))
                self._emit(_instr(Op.SHL))
            self._emit(_instr(Op.LOCAL_GET, acc_slot))
            self._emit(_instr(Op.BOR))
            self._emit(_instr(Op.LOCAL_SET, acc_slot))

        self._emit(_instr(Op.LOCAL_GET, acc_slot))
        self._emit(_instr(Op.CAST, target_ttag))

    def _visit_fp_decl(self, node: FunctionPointerDeclaration):
        """
        Function pointer declaration: def{}* pb() -> void = @bar;
        @bar stores Val(TTag.BYTES, func_name) in a named slot, then
        pb holds Val(TTag.PTR, that_slot) — same as @x for variables.
        """
        fp_slot = self._alloc_local(node.name)
        if node.initializer is not None:
            self._visit_expr(node.initializer)
        else:
            self._emit(_instr(Op.PUSH, Val(TTag.PTR, 0)))
        self._emit(_instr(Op.LOCAL_SET, fp_slot))
        self._local_types[node.name] = '__funcptr__'

    def _visit_function_def(self, node: FunctionDef):
        """
        Compile a comptime function definition and store its bytecode in
        self.compiled_functions so the caller (visit_ComptimeBlock in fcodegen.py)
        can register it with the VM before execute().
        Parameters are pre-loaded into local slots 0..N-1 by the VM _call() mechanism.
        """
        fn_cg = FVMCodegen(known_functions=dict(self._known_functions))
        fn_cg._outer_globals = set(self._block_globals)
        fn_cg._using_namespaces = list(self._using_namespaces)
        fn_cg._struct_layouts = dict(self._struct_layouts)
        fn_cg._enum_names = set(self._enum_names)
        fn_cg._macro_table = dict(self._macro_table)
        # Allocate a slot for each parameter so LOCAL_GET/SET work by name
        for param in node.parameters:
            fn_cg._alloc_local(param.name)
        # <~ strict recursion: self-calls and returns in this body emit TAIL_SELF
        if node.is_recursive:
            fn_cg._tail_call_self = node.name
            fn_cg._tail_call_argc = len(node.parameters)
        # Compile the body
        body_stmts = (
            node.body.statements if isinstance(node.body, Block) else [node.body]
        )
        fn_cg._visit_body(body_stmts)
        if node.is_recursive:
            # <~ function: _visit_return already emits TAIL_SELF inline.
            # If the body did not explicitly terminate, append the implicit
            # self tail-call (mirrors the runtime musttail insertion).
            argc = len(node.parameters)
            last = fn_cg._instructions[-1].op if fn_cg._instructions else None
            if last not in (Op.TAIL_SELF, Op.RET):
                fn_cg._emit(_instr(Op.TAIL_SELF, argc))
        else:
            # Normal function: ensure every path ends with RET.
            if not fn_cg._instructions or fn_cg._instructions[-1].op != Op.RET:
                from fvm import TTag as _TTag
                fn_cg._emit(_instr(Op.PUSH, Val(_TTag.VOID, 0)))
                fn_cg._emit(_instr(Op.RET))
        # Mark the original node so the LLVM codegen skips any template
        # instantiation that deep-copies it (fparser propagates this flag).
        node._is_comptime_only = True
        # Propagate nested function definitions upward
        self.compiled_functions.update(fn_cg.compiled_functions)
        self.compiled_functions[node.name] = fn_cg._instructions
        # Mark the original node so the LLVM codegen skips it unconditionally,
        # regardless of when _comptime_functions is populated.
        node._is_comptime_only = True

    def _visit_type_func_def(self, node: TypeFuncDef):
        """
        Compile a comptime type function definition.
        Registered under TypeFuncDef.mangle(type_name, func_name) so that
        TypeFuncCall sites can find it by the same mangled name.
        The implicit receiver parameter '_' occupies slot 0.
        """
        fn_cg = FVMCodegen(known_functions=dict(self._known_functions))
        fn_cg._outer_globals = set(self._block_globals)
        fn_cg._using_namespaces = list(self._using_namespaces)
        fn_cg._struct_layouts = dict(self._struct_layouts)
        fn_cg._enum_names = set(self._enum_names)
        fn_cg._macro_table = dict(self._macro_table)
        # Slot 0: implicit receiver '_'
        fn_cg._alloc_local('_')
        # Explicit parameters follow
        for param in node.parameters:
            fn_cg._alloc_local(param.name)
        body_stmts = (
            node.body.statements if isinstance(node.body, Block) else [node.body]
        )
        fn_cg._visit_body(body_stmts)
        if not fn_cg._instructions or fn_cg._instructions[-1].op != Op.RET:
            from fvm import TTag as _TTag
            fn_cg._emit(_instr(Op.PUSH, Val(_TTag.VOID, 0)))
            fn_cg._emit(_instr(Op.RET))
        self.compiled_functions.update(fn_cg.compiled_functions)
        mangled = TypeFuncDef.mangle(node.type_name, node.func_name)
        self.compiled_functions[mangled] = fn_cg._instructions
        node._is_comptime_only = True

    def _type_bit_width(self, ts) -> int:
        """
        Compute the bit width of a TypeSystem without llvmlite.
        Flux structs are tightly packed — no padding.
        """
        from ftypesys import DataType as _DT
        if ts is None:
            return 32
        if ts.bit_width is not None:
            return ts.bit_width
        if ts.is_pointer:
            return 64
        if ts.is_array and ts.array_size and ts.base_type is not None:
            elem_bits = self._type_bit_width_base(ts.base_type, ts)
            arr_size = ts.array_size
            if hasattr(arr_size, 'value'):  # Literal node
                arr_size = int(arr_size.value)
            return elem_bits * int(arr_size)
        if ts.base_type is not None:
            return self._type_bit_width_base(ts.base_type, ts)
        if ts.custom_typename is not None:
            # Nested struct — look up in our own registry
            layout = self._struct_layouts.get(ts.custom_typename)
            if layout is not None:
                return layout.total_bits if layout.total_bits else layout.total_size * 8
        return 32

    def _type_bit_width_base(self, base_type, ts=None) -> int:
        from ftypesys import DataType as _DT
        _map = {
            _DT.SINT: 32, _DT.UINT: 32,
            _DT.SLONG: 64, _DT.ULONG: 64,
            _DT.FLOAT: 32, _DT.DOUBLE: 64,
            _DT.BOOL: 1, _DT.BYTE: 8, _DT.CHAR: 8,
            _DT.DATA: ts.bit_width if ts and ts.bit_width else 0,
        }
        return _map.get(base_type, 32)

    def _type_ttag_from_ts(self, ts) -> TTag:
        """Map a TypeSystem to the closest VM TTag."""
        from ftypesys import DataType as _DT
        if ts is None:
            return TTag.INT
        if ts.is_pointer:
            return TTag.PTR
        if ts.custom_typename is not None:
            _prim = _prim_alias_ttag(ts.custom_typename)
            if _prim is not None:
                return _prim
            return TTag.STRUCT
        if ts.base_type is not None:
            return _datatype_to_ttag(ts.base_type)
        return TTag.INT

    def _visit_struct_def(self, node: StructDef, prefix: str = ''):
        """
        Compute a StructLayout for this struct and register it.
        Flux structs are tightly packed — zero padding between fields.
        Handles nested structs recursively.
        """
        from fvm import StructLayout as _SL
        from ftypesys import DataType as _DT

        full_name = f'{prefix}__{node.name}' if prefix else node.name

        # Recurse into nested structs first so their layouts are available
        for nested in node.nested_structs:
            self._visit_struct_def(nested, prefix=full_name)

        fields = []
        byte_offset = 0
        total_bits = 0
        for member in node.members:
            bits = self._type_bit_width(member.type_spec)
            byte_size = max(1, (bits + 7) // 8)
            ttag = self._type_ttag_from_ts(member.type_spec)
            fields.append((member.name, ttag, byte_offset, byte_size))
            byte_offset += byte_size
            total_bits += bits

        layout = _SL(name=full_name, fields=fields, total_size=byte_offset, total_bits=total_bits)
        self._struct_layouts[full_name] = layout
        # Also register under bare name for convenience
        if prefix:
            self._struct_layouts[node.name] = layout
        node._is_comptime_only = True

    def _visit_struct_instance(self, node: StructInstance) -> bool:
        self._emit(_instr(Op.STRUCT_NEW, node.struct_name))
        tmp_slot = self._alloc_local('__struct_tmp__')
        self._emit(_instr(Op.LOCAL_SET, tmp_slot))
        for fname, fexpr in (node.field_values or {}).items():
            self._emit(_instr(Op.LOCAL_GET, tmp_slot))
            self._visit_expr(fexpr)
            self._emit(_instr(Op.STRUCT_STORE, fname))
            self._emit(_instr(Op.LOCAL_SET, tmp_slot))
        self._emit(_instr(Op.LOCAL_GET, tmp_slot))
        return True

    def _visit_struct_literal(self, node: StructLiteral) -> bool:
        """
        Struct literal {field=val, ...} — requires struct_type to be set.
        """
        if node.struct_type is None:
            raise FVMCodegenError(
                'fvmcodegen: StructLiteral has no struct_type in comptime', node)
        self._emit(_instr(Op.STRUCT_NEW, node.struct_type))
        tmp_slot = self._alloc_local('__struct_lit_tmp__')
        self._emit(_instr(Op.LOCAL_SET, tmp_slot))
        for fname, fexpr in (node.field_values or {}).items():
            self._emit(_instr(Op.LOCAL_GET, tmp_slot))
            self._visit_expr(fexpr)
            self._emit(_instr(Op.STRUCT_STORE, fname))
            self._emit(_instr(Op.LOCAL_SET, tmp_slot))
        if node.positional_values:
            layout = self._struct_layouts.get(node.struct_type)
            if layout:
                for (fname, _, _, _), fexpr in zip(layout.fields, node.positional_values):
                    self._emit(_instr(Op.LOCAL_GET, tmp_slot))
                    self._visit_expr(fexpr)
                    self._emit(_instr(Op.STRUCT_STORE, fname))
                    self._emit(_instr(Op.LOCAL_SET, tmp_slot))
        self._emit(_instr(Op.LOCAL_GET, tmp_slot))
        return True

    def _visit_struct_recast(self, node: StructRecast) -> bool:
        """
        StructRecast: T t from src
        Zero-copy reinterpretation. The destination slot receives a
        Val(TTag.PTR, src_slot, meta={struct_type, stack_slot, field_bit_offsets})
        pointing directly at the source frame slot. No heap allocation,
        no data movement. FIELD_GET/FIELD_SET on a stack_slot pointer
        extract/pack bits from the integer value in that slot directly.
        Source is invalidated by name.
        """
        layout = self._struct_layouts.get(node.target_type)
        if layout is None:
            raise FVMCodegenError(
                f'fvmcodegen: StructRecast: unknown struct type {node.target_type!r}', node)

        if not isinstance(node.source_expr, Identifier):
            raise FVMCodegenError(
                f'fvmcodegen: StructRecast source must be a simple identifier in comptime', node)

        src_name = node.source_expr.name
        if src_name not in self._locals:
            raise FVMCodegenError(
                f'fvmcodegen: StructRecast: source {src_name!r} not found in locals', node)
        src_slot = self._locals[src_name]

        # Pre-compute bit offsets for each field (LSB-first packed layout)
        _precise = {TTag.BOOL: 1, TTag.BYTE: 8, TTag.CHAR: 8,
                    TTag.INT: 32, TTag.UINT: 32,
                    TTag.LONG: 64, TTag.ULONG: 64,
                    TTag.FLOAT: 32, TTag.DOUBLE: 64}
        field_bit_offsets = {}
        bit_cursor = 0
        for fname, fttag, _byte_off, fbyte_size in layout.fields:
            field_bit_offsets[fname] = bit_cursor
            bit_cursor += _precise.get(fttag, fbyte_size * 8)

        # Emit STRUCT_NEW and populate each field by extracting bits from src
        self._emit(_instr(Op.STRUCT_NEW, node.target_type))
        tmp_slot = self._alloc_local('__recast_tmp__')
        self._emit(_instr(Op.LOCAL_SET, tmp_slot))
        for fname, fttag, _byte_off, fbyte_size in layout.fields:
            bit_off = field_bit_offsets.get(fname, 0)
            fbit_w  = _precise.get(fttag, fbyte_size * 8)
            mask    = (1 << fbit_w) - 1
            # LOCAL_GET src >> bit_off & mask
            self._emit(_instr(Op.LOCAL_GET, src_slot))
            if bit_off:
                self._emit(_instr(Op.PUSH, Val(TTag.INT, bit_off)))
                self._emit(_instr(Op.SHR))
            self._emit(_instr(Op.PUSH, Val(TTag.LONG, mask)))
            self._emit(_instr(Op.BAND))
            self._emit(_instr(Op.CAST, fttag))
            # STRUCT_STORE field -> write back
            self._emit(_instr(Op.LOCAL_GET, tmp_slot))
            self._emit(_instr(Op.SWAP))
            self._emit(_instr(Op.STRUCT_STORE, fname))
            self._emit(_instr(Op.LOCAL_SET, tmp_slot))
        self._emit(_instr(Op.LOCAL_GET, tmp_slot))

        # Invalidate source by name; slot index still exists but unreachable.
        if not getattr(node, 'suppress_invalidate', False):
            if src_name in self._locals:
                del self._locals[src_name]
            if src_name in self._local_types:
                del self._local_types[src_name]

        return True

    def _visit_member_access(self, node: MemberAccess) -> bool:
        """
        obj.member - struct field access or namespace path component.
        """
        if isinstance(node.object, Identifier):
            var_name = node.object.name
            type_name = self._local_types.get(var_name)
            if var_name in self._locals:
                if type_name and type_name in self._enum_names:
                    # me1._ -> ENUM_LOAD
                    self._visit_expr(node.object)
                    self._emit(_instr(Op.ENUM_LOAD))
                    return True
                # Struct field access: use STRUCT_LOAD
                self._visit_expr(node.object)
                self._emit(_instr(Op.STRUCT_LOAD, node.member))
                return True
            # Identifier not a known local - namespace path prefix, push nothing
            return False
        elif isinstance(node.object, MemberAccess):
            produced = self._visit_member_access(node.object)
            if produced:
                self._emit(_instr(Op.STRUCT_LOAD, node.member))
                return True
            return False
        # Generic: evaluate object and STRUCT_LOAD
        self._visit_expr(node.object)
        self._emit(_instr(Op.STRUCT_LOAD, node.member))
        return True

    def _visit_struct_field_access(self, node: StructFieldAccess) -> bool:
        self._visit_expr(node.struct_instance)
        self._emit(_instr(Op.STRUCT_LOAD, node.field_name))
        return True

    def _visit_struct_field_assign(self, node: StructFieldAssign):
        self._visit_expr(node.struct_instance)
        self._visit_expr(node.value)
        self._emit(_instr(Op.STRUCT_STORE, node.field_name))

    def _visit_enum_def(self, node: EnumDef):
        """
        Enum definition: register each value as a comptime local integer.
        e.g. enum MyEnum { Thing1, Thing2, Thing3 } ->
             Thing1=0, Thing2=1, Thing3=2 as INT locals.
        Also guards the LLVM codegen from visiting this node.
        """
        self._enum_names.add(node.name)
        for name, value in node.values.items():
            slot = self._alloc_local(name)
            self._emit(_instr(Op.PUSH, Val(TTag.INT, int(value))))
            self._emit(_instr(Op.LOCAL_SET, slot))
            self._local_types[name] = 'int'
        node._is_comptime_only = True

    def _visit_union_def(self, node: UnionDef):
        """
        Compute a StructLayout for a union.
        All members share offset 0; total size is the largest member size.
        Uses the same VM machinery as structs (STRUCT_NEW, FIELD_GET, FIELD_SET).
        """
        from fvm import StructLayout as _SL

        fields = []
        max_byte_size = 0
        for member in node.members:
            bits = self._type_bit_width(member.type_spec)
            byte_size = max(1, (bits + 7) // 8)
            ttag = self._type_ttag_from_ts(member.type_spec)
            fields.append((member.name, ttag, 0, byte_size))  # all at offset 0
            max_byte_size = max(max_byte_size, byte_size)

        layout = _SL(name=node.name, fields=fields, total_size=max_byte_size)
        self._struct_layouts[node.name] = layout
        node._is_comptime_only = True

    def _visit_extern_block(self, node: ExternBlock):
        """
        Register extern function prototypes with the VM so they can be called
        via ctypes at comptime runtime. Emits EXTERN_DECL instructions for
        each prototype so the VM's _extern_protos dict is populated.
        """
        for decl in (node.declarations or []):
            ret_ttag = self._type_ttag_from_ts(decl.return_type) if decl.return_type is not None else TTag.VOID
            self._emit(_instr(Op.EXTERN_DECL, decl.name, ret_ttag))

    def _visit_namespace_def(self, node: NamespaceDef, prefix: str = ''):
        """
        Compile a comptime namespace definition.

        Functions are registered under their fully-qualified mangled name
        (e.g. A__foo for namespace A { def foo... }).  Nested namespaces
        are recursed with the accumulated prefix.  Structs, objects, enums,
        and unions are ignored — they have no runtime representation in the VM.
        """
        ns_name = f'{prefix}__{node.name}' if prefix else node.name
        node._is_comptime_only = True

        for func in node.functions:
            if func is None:
                continue
            fn_cg = FVMCodegen(known_functions=self._known_functions)
            fn_cg._outer_globals = set(self._block_globals)
            for param in func.parameters:
                fn_cg._alloc_local(param.name)
            body_stmts = (
                func.body.statements if isinstance(func.body, Block) else [func.body]
            )
            fn_cg._visit_body(body_stmts)
            if not fn_cg._instructions or fn_cg._instructions[-1].op != Op.RET:
                from fvm import TTag as _TTag
                fn_cg._emit(_instr(Op.PUSH, Val(_TTag.VOID, 0)))
                fn_cg._emit(_instr(Op.RET))
            self.compiled_functions.update(fn_cg.compiled_functions)
            mangled = f'{ns_name}__{func.name}'
            self.compiled_functions[mangled] = fn_cg._instructions
            func._is_comptime_only = True

        for struct in node.structs:
            self._visit_struct_def(struct, prefix=ns_name)

        for extern_block in node.extern_blocks:
            self._visit_extern_block(extern_block)

        for var in (node.variables or []):
            # global variables in a namespace are initialized and registered as block globals
            self._visit_var_decl(var)
            self._block_globals.add(var.name)

        for nested in node.nested_namespaces:
            self._visit_namespace_def(nested, prefix=ns_name)

    def _visit_using(self, node):
        ns = node.namespace_path.replace('::', '__')
        if ns not in self._excluded_namespaces and ns not in self._using_namespaces:
            self._using_namespaces.append(ns)

    def _visit_not_using(self, node):
        ns = node.namespace_path.replace('::', '__')
        self._excluded_namespaces.add(ns)
        if ns in self._using_namespaces:
            self._using_namespaces.remove(ns)

    def _visit_switch(self, node: SwitchStatement):
        """
        Compile a switch statement.

        Strategy: evaluate the subject once into a temp slot, then for each
        non-default case emit CMP_EQ + JNF to skip the body.  The default
        case (Case.value is None) is emitted last and always falls through.
        break inside a case body jumps past the entire switch.
        """
        # Evaluate subject expression and store in a temp local
        self._visit_expr(node.expression)
        subject_slot = self._alloc_local('__switch_subject__')
        self._emit(_instr(Op.LOCAL_SET, subject_slot))

        break_patches: List[int] = []
        default_case: Optional[Case] = None

        for case in node.cases:
            if case.value is None:
                # defer default to end
                default_case = case
                continue

            # Push subject and case value, compare
            self._emit(_instr(Op.LOCAL_GET, subject_slot))
            self._visit_expr(case.value)
            self._emit(_instr(Op.CMP_EQ))
            skip_patch = self._emit(_instr(Op.JNF, 0))

            # Emit case body; intercept break
            body_stmts = (
                case.body.statements if isinstance(case.body, Block) else [case.body]
            )
            for stmt in body_stmts:
                if stmt is None:
                    continue
                if type(stmt) is BreakStatement:
                    break_patches.append(self._emit(_instr(Op.JMP, 0)))
                else:
                    self._visit_stmt(stmt)

            # Jump past the switch after a matched (non-breaking) case body
            break_patches.append(self._emit(_instr(Op.JMP, 0)))
            self._patch_at(skip_patch, Op.JNF, self._current_ip())

        # Emit default case body if present
        if default_case is not None:
            body_stmts = (
                default_case.body.statements
                if isinstance(default_case.body, Block)
                else [default_case.body]
            )
            for stmt in body_stmts:
                if stmt is None:
                    continue
                if type(stmt) is BreakStatement:
                    break_patches.append(self._emit(_instr(Op.JMP, 0)))
                else:
                    self._visit_stmt(stmt)

        after_switch = self._current_ip()
        for idx in break_patches:
            self._patch_at(idx, Op.JMP, after_switch)

    def _visit_for(self, node: ForLoop):
        if node.init is not None:
            self._visit_stmt(node.init)

        loop_start = self._current_ip()

        exit_patch = None
        if node.condition is not None:
            self._visit_expr(node.condition)
            exit_patch = self._emit(_instr(Op.JNF, 0))

        break_patches:    List[int] = []
        continue_patches: List[int] = []

        body_stmts = (
            node.body.statements if isinstance(node.body, Block) else [node.body]
        )
        for stmt in body_stmts:
            if stmt is None:
                continue
            if type(stmt) is BreakStatement:
                break_patches.append(self._emit(_instr(Op.JMP, 0)))
            elif type(stmt) is ContinueStatement:
                continue_patches.append(self._emit(_instr(Op.JMP, 0)))
            else:
                self._visit_stmt(stmt)

        update_ip = self._current_ip()
        if node.update is not None:
            self._visit_stmt(node.update)

        self._emit(_instr(Op.JMP, loop_start))
        after_loop = self._current_ip()

        if exit_patch is not None:
            self._patch_at(exit_patch, Op.JNF, after_loop)
        for idx in continue_patches:
            self._patch_at(idx, Op.JMP, update_ip)
        for idx in break_patches:
            self._patch_at(idx, Op.JMP, after_loop)

    def _visit_while(self, node: WhileLoop):
        loop_start = self._current_ip()
        self._visit_expr(node.condition)
        exit_patch = self._emit(_instr(Op.JNF, 0))

        break_patches:    List[int] = []
        continue_patches: List[int] = []
        body_stmts = (
            node.body.statements if isinstance(node.body, Block) else [node.body]
        )
        for stmt in body_stmts:
            if stmt is None:
                continue
            if type(stmt) is BreakStatement:
                break_patches.append(self._emit(_instr(Op.JMP, 0)))
            elif type(stmt) is ContinueStatement:
                continue_patches.append(self._emit(_instr(Op.JMP, 0)))
            else:
                self._visit_stmt(stmt)

        self._emit(_instr(Op.JMP, loop_start))
        after_loop = self._current_ip()
        self._patch_at(exit_patch, Op.JNF, after_loop)
        for idx in break_patches:
            self._patch_at(idx, Op.JMP, after_loop)
        for idx in continue_patches:
            self._patch_at(idx, Op.JMP, loop_start)

    def _visit_label(self, node: LabelStatement):
        """Record the current IP as the target for this label name."""
        self._labels[node.name] = self._current_ip()
        # Resolve any forward gotos that were waiting for this label
        remaining = []
        for idx, target in self._goto_patches:
            if target == node.name:
                self._patch_at(idx, Op.JMP, self._current_ip())
            else:
                remaining.append((idx, target))
        self._goto_patches = remaining

    def _visit_goto(self, node: GotoStatement):
        """Emit a JMP to the target label, patching later if forward reference."""
        if node.target in self._labels:
            self._emit(_instr(Op.JMP, self._labels[node.target]))
        else:
            patch_idx = self._emit(_instr(Op.JMP, 0))
            self._goto_patches.append((patch_idx, node.target))

    def _visit_jump(self, node: JumpStatement):
        """
        jump expr — low-level jump to an address expression.
        In the VM context, if the expression is a label address we resolve it;
        otherwise treat as a goto to whatever the expression evaluates to.
        """
        from fast import Identifier as _Id
        if isinstance(node.target, _Id) and node.target.name in self._labels:
            self._emit(_instr(Op.JMP, self._labels[node.target.name]))
        elif isinstance(node.target, _Id):
            patch_idx = self._emit(_instr(Op.JMP, 0))
            self._goto_patches.append((patch_idx, node.target.name))
        else:
            # Dynamic address — evaluate and jump (best-effort)
            self._visit_expr(node.target)
            # No direct indirect-jump in VM; fall through silently

    def _resolve_goto_patches(self):
        """Resolve any remaining goto patches after a body is fully emitted."""
        for idx, target in self._goto_patches:
            if target in self._labels:
                self._patch_at(idx, Op.JMP, self._labels[target])
        self._goto_patches = [(i, t) for i, t in self._goto_patches
                              if t not in self._labels]

    def _visit_do(self, node: DoLoop):
        """Plain do loop: infinite loop, only exits via break."""
        loop_start = self._current_ip()
        break_patches: List[int] = []
        continue_patches: List[int] = []
        body_stmts = (
            node.body.statements if isinstance(node.body, Block) else [node.body]
        )
        for stmt in body_stmts:
            if stmt is None:
                continue
            if type(stmt) is BreakStatement:
                break_patches.append(self._emit(_instr(Op.JMP, 0)))
            elif type(stmt) is ContinueStatement:
                continue_patches.append(self._emit(_instr(Op.JMP, loop_start)))
            else:
                self._visit_stmt(stmt)
        self._emit(_instr(Op.JMP, loop_start))
        after_loop = self._current_ip()
        for idx in break_patches:
            self._patch_at(idx, Op.JMP, after_loop)

    def _visit_do_while(self, node: DoWhileLoop):
        loop_start = self._current_ip()
        break_patches:    List[int] = []
        continue_patches: List[int] = []
        body_stmts = (
            node.body.statements if isinstance(node.body, Block) else [node.body]
        )
        for stmt in body_stmts:
            if stmt is None:
                continue
            if type(stmt) is BreakStatement:
                break_patches.append(self._emit(_instr(Op.JMP, 0)))
            elif type(stmt) is ContinueStatement:
                continue_patches.append(self._emit(_instr(Op.JMP, 0)))
            else:
                self._visit_stmt(stmt)
        cond_ip = self._current_ip()
        self._visit_expr(node.condition)
        self._emit(_instr(Op.JIF, loop_start))
        after_loop = self._current_ip()
        for idx in break_patches:
            self._patch_at(idx, Op.JMP, after_loop)
        for idx in continue_patches:
            self._patch_at(idx, Op.JMP, cond_ip)

    def _visit_return(self, node: ReturnStatement):
        if node.value is not None and isinstance(node.value, Identifier) and node.value.name in self._local_vars:
            raise FVMCodegenError(
                f"fvmcodegen: local variable '{node.value.name}' cannot escape scope (returned from function)",
                node)
        if node.value is not None:
            self._visit_expr(node.value)
        else:
            self._emit(_instr(Op.PUSH, Val(TTag.VOID, 0)))
        # Inside a <~ function every return is a re-entry, not an exit.
        # escape bypasses this by calling _visit_escape directly.
        if self._tail_call_self is not None:
            self._emit(_instr(Op.TAIL_SELF, self._tail_call_argc))
        else:
            self._emit(_instr(Op.RET))

    def _visit_escape(self, node: EscapeStatement):
        """
        escape call; -- exits strict recursion by making a normal non-tail call.
        Temporarily clears _tail_call_self so the inner call emits CALL not TAIL_SELF,
        then restores it. The return value of the escaped call becomes the return
        value of the <~ function, ending the tail-call loop.
        """
        saved = self._tail_call_self
        self._tail_call_self = None
        self._visit_expr(node.call)
        self._tail_call_self = saved
        self._emit(_instr(Op.RET))

    def _visit_break(self, node: BreakStatement):
        self._emit(_instr(Op.JMP, 0))  # patched by enclosing loop visitor

    def _visit_continue(self, node: ContinueStatement):
        self._emit(_instr(Op.JMP, 0))  # patched by enclosing loop visitor

    # ------------------------------------------------------------------
    # emitflux
    # ------------------------------------------------------------------

    def _visit_fluxvm_block(self, node: FluxVMBlock):
        """
        fluxvm { OP [operands...] } -- inline FVM bytecode.
        Each non-empty line is one instruction:
          first token  = Op name  resolved via Op[name]
          remaining    = operands: integer literals, quoted strings,
                         local variable names (resolved to slot index),
                         or TTag names (resolved via TTag[name]).
        Op names are taken directly from the Op enum so no separate
        table is needed -- adding a new Op automatically makes it available.
        """
        from fvm import Op as _Op, TTag as _TTag
        for raw_line in node.body.splitlines():
            line = raw_line.strip()
            if not line or line.startswith('//'):
                continue
            # Strip inline comment
            if '/' in line:
                line = line[:line.index('/')].strip()
            if not line:
                continue
            parts = line.split()
            op_name = parts[0].upper()
            try:
                op = _Op[op_name]
            except KeyError:
                raise FVMCodegenError(
                    f'fluxvm: unknown opcode {op_name!r}', node)
            raw_operands = []
            for tok in parts[1:]:
                # Integer literal (decimal or hex or binary)
                try:
                    raw_operands.append(int(tok, 0))
                    continue
                except ValueError:
                    pass
                # Quoted string literal
                if (tok.startswith('"') and tok.endswith('"')) or \
                   (tok.startswith("'") and tok.endswith("'")):
                    raw_operands.append(tok[1:-1])
                    continue
                # TTag name (e.g. INT, BOOL, ULONG)
                try:
                    raw_operands.append(_TTag[tok.upper()])
                    continue
                except KeyError:
                    pass
                # Local variable name -> slot index
                if tok in self._locals:
                    raw_operands.append(self._locals[tok])
                    continue
                raise FVMCodegenError(
                    f'fluxvm: unresolved operand {tok!r} on line {line!r}', node)
            # PUSH requires a Val, not a raw value.
            # Syntax: PUSH <value> [TTAG]  -- TTAG defaults to INT for integers,
            #         BYTES for strings.
            if op == _Op.PUSH:
                if not raw_operands:
                    raise FVMCodegenError('fluxvm: PUSH requires a value operand', node)
                value = raw_operands[0]
                if len(raw_operands) >= 2 and isinstance(raw_operands[1], _TTag):
                    ttag = raw_operands[1]
                elif isinstance(value, str):
                    ttag = _TTag.BYTES
                    value = value.encode('utf-8')
                elif isinstance(value, float):
                    ttag = _TTag.DOUBLE
                else:
                    ttag = _TTag.INT
                self._emit(_instr(op, Val(ttag, value)))
            else:
                self._emit(_instr(op, *raw_operands))

    def _visit_emitflux(self, node: EmitFlux):
        """
        Emit an EMITFLUX opcode.  Operands:
          [0] source_text : str              -- raw Flux text with placeholder names
          [1] var_names   : [(name, slot)]   -- snapshot of current locals

        At VM execution time the actual values in those slots are used for
        variable substitution in _op_emitflux().
        """
        var_snapshot = list(self._locals.items())  # [(name, slot), ...]
        self._emit(_instr(Op.EMITFLUX, node.source_text, var_snapshot))