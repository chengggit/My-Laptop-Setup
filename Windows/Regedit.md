## Tune CPU with Power Option
### Unlock Limit CPU Boost Clock
For Intel 12th Gen and above.

`Computer\HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\75b0ae3f-bce0-45a7-8c89-c9611c25e101`

| Key | Value |
| --------------------- | ----- |
| Attributes | 2 |

OP: [Reddit](https://www.reddit.com/r/Alienware/comments/xgoel1/you_can_limit_the_12700h_clock_speed_with_this/?share_id=eFB9krs7CJgyT_UO54afM&utm_medium=android_app&utm_name=androidcss&utm_source=share&utm_term=1)

My power option setting:
- On Battery: 3700MHz
- Plugged In: 4200MHz

### Unlock Processor Performance Boost Mode
`Computer\HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\be337238-0d82-4146-a960-4f3749d470c7`
| Key | Value |
| --------------------- | ----- |
| Attributes | 2 |

In power option set to **Efficient Agressive**.

## My Filter Keys

`Computer\HKEY_CURRENT_USER\Control Panel\Accessibility\Keyboard Response`

| Key                   | Value |
| --------------------- | ----- |
| AutoRepeatDelay       | 200   |
| AutoRepeatRate        | 10    |
| BounceTime            | 0     |
| DelayBeforeAcceptance | 0     |
| Flags                 | 51    |
