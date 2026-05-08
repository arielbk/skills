# TDD Loop

Apply this loop for each behavior within a slice.

## Red → Green → Refactor

```
RED:    Write one test for one behavior → it fails
GREEN:  Write minimal code to make it pass → it passes
REPEAT: Next behavior
REFACTOR: After all behaviors pass, clean up duplication and deepen modules
```

**Never refactor while RED.** Get to GREEN first.

## Anti-pattern: horizontal slicing

DO NOT write all tests first, then all implementation.

```
WRONG:
  RED:   test1, test2, test3, test4
  GREEN: impl1, impl2, impl3, impl4

RIGHT:
  RED→GREEN: test1→impl1
  RED→GREEN: test2→impl2
  ...
```

Writing tests in bulk produces tests that verify imagined behavior, not actual behavior. You outrun your headlights.

## Good tests

- Exercise real code paths through public interfaces
- Describe what the system does, not how
- Survive internal refactors — if you rename an internal function and the test breaks, it was testing implementation
- Read like a specification: "user can checkout with valid cart"

## Checklist per cycle

- [ ] Test describes behavior, not implementation
- [ ] Test uses public interface only  
- [ ] Test would survive internal refactor
- [ ] Code is minimal for this test
- [ ] No speculative features added
