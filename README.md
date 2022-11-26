# YOZZ

YOZZ will be the next generation web framework, providing both **blazingly fast** backend performance through ZIG, but also frontend performance using **WASM**.

*YOZZ is still in heavy development. There are no releases yet*

### Blazingly fast?

A big part of ZIG's compiler is the `comptime` keyword. This allows expressions to be executed at Runtime. Most HTTP frameworks allow for dynamic HTTP response generation at runtime, which you mostly don't need. YOZZ provides codegen to pregenerate certain parts of the HTTP response (like the Statusline for example), which makes it truly **blazingly Fast**.
