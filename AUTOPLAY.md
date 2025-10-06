# Autoplay System

Automated execution system for Z-Machine story files, enabling testing, walkthroughs, and continuous integration workflows.

## Activation

Run a story file with an instruction script:

```bash
zil autoplay story.z3 script.txt
```

## Basic Syntax

### Commands

Regular game commands are executed as-is:

```
open mailbox
read leaflet
go north
take lamp
```

### Directives

Directives start with `!` and control automation behavior:

```
!SET counter = value
!TRACK regex "pattern" counter
!LOOP
!UNTIL regex "pattern"
!IFCOUNTER name op value THEN
!END
!HEAL [counter]
!WAIT turns
!WAIT-UNTIL regex "pattern"
!MANUAL
```

### Comments

Lines starting with `#` are comments:

```
# This is a comment
# Take the lamp for light
take lamp
```

## Directives Reference

### Counter Management

**!SET counter = value**

Initialize or update a counter variable:

```
!SET health = 100
!SET attempts = 0
```

### Pattern Tracking

**!TRACK regex "pattern" counter**

Increment counter when pattern appears in game output:

```
!TRACK regex "You have died" deaths
!TRACK regex "score has just gone up" score_increases
```

Pattern matching is case-sensitive and uses Swift Regex syntax.

### Loop Control

**!LOOP ... !UNTIL regex "pattern"**

Repeat commands until pattern appears:

```
!LOOP
north
!UNTIL regex "You have reached the summit"
```

Loops can be nested for complex scenarios.

### Conditional Execution

**!IFCOUNTER name op value THEN ... !END**

Execute commands based on counter value:

```
!IFCOUNTER deaths > 5 THEN
  # Too many deaths, abort
  quit
!END
```

**Operators:**
- `==` - Equal
- `!=` - Not equal
- `<` - Less than
- `>` - Greater than
- `<=` - Less than or equal
- `>=` - Greater than or equal

### Automated Healing

**!HEAL [counter]**

Automated health restoration sequence:

```
!HEAL
!HEAL deaths  # Track deaths during healing
```

**Behavior:**
- Waits until health drops below threshold
- Drops sword to enable healing spell
- Casts CASKLY repeatedly until healed
- Picks up sword when done
- Manages lamp during darkness

### Wait Sequences

**!WAIT turns**

Wait for specified number of turns:

```
!WAIT 10
```

**!WAIT-UNTIL regex "pattern"**

Wait until pattern appears:

```
!WAIT-UNTIL regex "The door swings open"
```

### Manual Mode

**!MANUAL**

Switch to manual input mode:

```
!MANUAL
```

User can type commands interactively. Automated sequences (HEAL, WAIT) still execute automatically.

## Examples

### Basic Walkthrough

```
# Zork I opening sequence
open mailbox
read leaflet
go south
go west
open window
go west
take lamp
turn on lamp
go east
go up
```

### Combat with Healing

```
!SET deaths = 0
!TRACK regex "You have died" deaths

# Enter combat area
go east
attack troll with sword

# Automated healing
!HEAL deaths

# Continue after healing
go north
```

### Loop Until Success

```
!SET attempts = 0

!LOOP
!SET attempts = attempts + 1
throw bottle at mirror
!UNTIL regex "The mirror shatters"

# Check attempts
!IFCOUNTER attempts > 10 THEN
  # This shouldn't happen
  quit
!END
```

### Conditional Logic

```
!SET score = 0
!TRACK regex "score has just gone up" score

take treasure
!IFCOUNTER score > 0 THEN
  # Score increased, treasure was valuable
  go north
!END

!IFCOUNTER score == 0 THEN
  # No score, try different approach
  drop treasure
  take other_item
!END
```

### Nested Loops

```
# Explore all rooms in area
!LOOP
  !LOOP
    north
  !UNTIL regex "You can't go that way"

  !LOOP
    east
  !UNTIL regex "You can't go that way"
!UNTIL regex "You have explored everything"
```

### Pattern Tracking

```
!SET moves = 0
!SET treasures = 0
!SET deaths = 0

!TRACK regex "^>" moves
!TRACK regex "taken\." treasures
!TRACK regex "died" deaths

# Execute gameplay
take all
go north
fight monster

# Results tracked in counters
```

## Advanced Features

### Auto-Timing

Autoplay adjusts delay between commands based on output length:

- Short output (< 100 chars): 0.5s delay
- Medium output (100-300 chars): 1.0s delay
- Long output (> 300 chars): 1.5s delay

Or use fixed timing:

```bash
zil autoplay story.z3 script.txt --delay 1.0
```

### Manual Override

Switch to manual mode at any point:

```
# Automated setup
take lamp
go north

# Switch to manual for puzzle
!MANUAL
# User takes over here
```

### Regex Patterns

Patterns use Swift Regex syntax:

```
!TRACK regex "score.*(\d+)" score_value
!UNTIL regex "^You (win|lose)"
!WAIT-UNTIL regex ".*ready.*"
```

**Tips:**
- Use `^` for start of line
- Use `.*` for any characters
- Use `\d+` for numbers
- Patterns are case-sensitive

### Output Accumulation

Patterns match across multiple output chunks:

```
# Game outputs: "The door" ... "slowly opens"
!WAIT-UNTIL regex "door.*opens"
# Matches even if output arrives in parts
```

## Best Practices

1. **Use comments liberally** - Document your automation logic
2. **Track important events** - Use !TRACK for deaths, score, key items
3. **Set realistic waits** - Allow time for game responses
4. **Test loops carefully** - Ensure !UNTIL conditions will be met
5. **Handle edge cases** - Use conditionals for different scenarios
6. **Validate counters** - Check counter values after tracking
7. **Manual mode for debugging** - Switch to manual when script fails

## Error Handling

### Common Issues

**Infinite loops:**
```
# BAD: Condition never met
!LOOP
  north
!UNTIL regex "impossible pattern"

# GOOD: Include fallback
!SET attempts = 0
!LOOP
  !SET attempts = attempts + 1
  north
  !IFCOUNTER attempts > 10 THEN
    quit
  !END
!UNTIL regex "You arrive"
```

**Pattern not matching:**
```
# Check pattern carefully
!TRACK regex "You died"  # Won't match "you died" (case-sensitive)
!TRACK regex "[Yy]ou died"  # Matches both
```

**Counter initialization:**
```
# BAD: Counter not initialized
!IFCOUNTER health < 50 THEN
  !HEAL
!END

# GOOD: Initialize first
!SET health = 100
!IFCOUNTER health < 50 THEN
  !HEAL
!END
```

## Use Cases

### Continuous Integration

```bash
# Run automated test suite
zil autoplay zork1.z3 test_suite.txt

# Check exit code
echo $?
```

### Walkthrough Testing

```
# Test complete game walkthrough
!SET moves = 0
!TRACK regex "^>" moves

# ... full walkthrough commands ...

!IFCOUNTER moves < 1000 THEN
  # Walkthrough completed efficiently
!END
```

### Speedrun Automation

```
!SET start_time = 0
# ... optimized command sequence ...
!SET end_time = 0
# Track completion time
```

### Regression Testing

```
# Test critical path
!SET score = 0
!TRACK regex "score.*350" max_score

# Execute test sequence
# ...

!IFCOUNTER max_score == 1 THEN
  # Test passed
!END
```

## Integration

### CI/CD Pipelines

```yaml
# GitHub Actions example
- name: Test Game
  run: |
    zil autoplay game.z3 tests/regression.txt
    if [ $? -eq 0 ]; then
      echo "Tests passed"
    fi
```

### Automated Testing

```bash
#!/bin/bash
for test in tests/*.txt; do
  echo "Running $test"
  zil autoplay game.z3 "$test" || exit 1
done
```

## Technical Details

### Command Queue

- Commands from script are queued for execution
- Manual mode bypasses queue for user input
- Automated sequences (HEAL, WAIT) inject commands into queue
- Queue executes in FIFO order

### Pattern Matching Scope

- Patterns match against accumulated output buffer
- Buffer persists across multiple `didOutputText()` calls
- Cleared after successful match
- Case-sensitive matching using Swift Regex

### Counter Scope

- Counters are global to the autoplay session
- Persist across loops and conditionals
- Can be read/written by any directive
- Integer values only

### Loop Execution

- Loops execute commands until condition met
- Maximum iteration safety limit prevents infinite loops
- Nested loops supported with proper scope handling
- !UNTIL checks after each command in loop body
