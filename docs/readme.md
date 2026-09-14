# Welcome to the documentation!

Here you can find what you need to learn and understand Flux.

The [keyword reference](https://github.com/kvthweatt/FluxLang/blob/main/docs/keyword_reference.md) will help you learn and use new keywords.

The [operator reference](https://github.com/kvthweatt/FluxLang/blob/main/docs/operator_reference.md) will help you learn the operators.

Undersanding Flux's type system will require leaving the world of C and other languages which have strict type safety.  
It's best to [start here](https://github.com/kvthweatt/FluxLang/blob/main/docs/learn_flux_intro.md).

Flux also has an [Effects System](https://github.com/kvthweatt/FluxLang/blob/main/docs/effects_system.md) which is a unique compile-time system for tracking, propagating, and constraining behavioral properties across call chains. Effects are labels. The operators applied to them are what give those labels meaning. Together they form a compiler programming interface that lets you describe and enforce what code does -- to memory, to the outside world, to other processes -- without any runtime cost. Everything is verified before the binary exists and erased before codegen.

The [standard library](https://github.com/kvthweatt/FluxLang/blob/main/docs/StandardLibrary/standard_library_v1.1.md) will help walk you through what is what and where.

There are setup guides for [Windows](https://github.com/kvthweatt/FluxLang/blob/main/docs/SetupGuides/windows_setup_guide.md) and [Linux](https://github.com/kvthweatt/FluxLang/blob/main/docs/SetupGuides/linux_setup_guide.md).

Every language needs a [style guide](https://github.com/kvthweatt/FluxLang/blob/main/docs/style_guide.md). This guide is a reflection of the standard library.

Information on the [Flux Virtual Machine](https://github.com/kvthweatt/FluxLang/blob/main/docs/fvm.md) and [Borrow Checker](https://github.com/kvthweatt/FluxLang/blob/main/docs/fbc.md)