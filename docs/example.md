# Player Controller

Design notes for the top-down player. Open the **Docs** tab to read this file rendered, or click a heading in the outline to jump.

## Movement

The player uses `CharacterBody2D` and moves in eight directions. Speed and acceleration are exported so they can be tuned in the Inspector.

| Property | Type | Default | Notes |
| --- | :---: | ---: | --- |
| `speed` | `float` | 120.0 | Pixels per second |
| `acceleration` | `float` | 900.0 | Higher feels snappier |
| `friction` | `float` | 1100.0 | Used when no input is held |

```gdscript
extends CharacterBody2D

@export var speed := 120.0
@export var acceleration := 900.0

func _physics_process(delta: float) -> void:
    var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    velocity = velocity.move_toward(input * speed, acceleration * delta)
    move_and_slide()  # Already accounts for delta.
```

> Keep gameplay values in exported variables instead of constants, so designers can tweak them without touching code.

## Checklist

- [x] Eight-direction movement
- [x] Camera follow with smoothing
- [ ] Dodge roll
  - Short invulnerability window
  - Cooldown shown in the HUD
- [ ] Footstep sounds

## Input map

```ini
[input]
move_left={ "deadzone": 0.5, "events": [...] }
shoot={ "deadzone": 0.5, "events": [...] }
```

See also the [Godot docs on CharacterBody2D](https://docs.godotengine.org/en/stable/classes/class_characterbody2d.html).
