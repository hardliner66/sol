# SOL - Steves Odin Library

This is a small collection of code I wrote, that I think might
be useful for others as well.

- [Opaque](#opaque)
- [Iter](#iter)
- [Fixed Dynamic Array](#fixed-dynamic-array)
  - [Fixed Dynamic Array / Iter](#fixed-dynamic-array--iter)
- [Expression Evaluator](#expression-evaluator)

## Opaque
Adds an opaque value type by basically reinterpreting a datatype as
an array of bytes and storing that (+ type info). This can be used
to write type-erased code, like the generic iterator.

**WARNING: This code transmutes. Use at your own risk.**

## Iter
The iter package defines an interface for iterators,
which can be implemented to allow functions to take an iterator,
without knowing exactly how it works underneath.

**WARNING: This code transmutes. Use at your own risk.**

I _think_ everything should work fine, but if you're unsure,
you probably want to avoid stuff related to iter and opaque.

## Fixed Dynamic Array
The name might seem like it contradicts itself,
but I couldn't think of a better one, so it has to do for now.

Its the same concept as [Small_Array](https://pkg.odin-lang.org/core/container/small_array/),
but uses heap allocated memory internally.
This makes it possible to decide the size at runtime,
while still having a static block of memory,
combined with the interface of a dynamic array.

_So append away and don't worry about keeping track where to put the next element!_

### Fixed Dynamic Array / Iter
It's iter time again. The `fixed_dynamic_array` library has a subfolder containing
the code for an iterator and code to safely manipulate the underlying container,
even while iterating.

I use this in a game I'm working on in order to remove projectiles and enemies
from the list once they are dead. This simplifies lifecycle management of those
entities and guarantees that they will always be in on contiguous block of memory.

As the Fixed Dynamic Array supports unordered removes, deleting an element is
basically just a decrement of the length plus moving one element.
Combined with the iterator, it should allow for a simple, yet still performant,
way to handle data in your application.

## Expression Evaluator
Also something I use in the game mentioned above.

If you ever have to need to do some calculations, but want to manage the formulas
inside a config file, this is for you. The parser automatically handles parenthesis
with the highest precedence and allows to configure the precedence for the rest.

This is only really useful if you're adding your own operators
(or when you're abusing operators for something crazy).

The evaluator allows you to pass variables that you can use in your formulas,
as well as changing or adding operators.

The code is built in a way, that you can either call `eval` directly with
some variables and a string, and quickly get an answer, but also so you
can call `parse` in order to get an array of expressions that can be evaluated
with a call to the `eval_expr` function. The second way is useful if you need to run
a formula multiple times, so you can cache the parsed expressions and
don't have to parse it over and over again.