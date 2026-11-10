extends Node
## Small glue singleton for global flags. Individual systems (time/economy/tanks/shop/events)
## each own their own autoload; this just holds cross-cutting state that doesn't belong to one.

var debug_mode: bool = OS.is_debug_build()
var first_run: bool = true
