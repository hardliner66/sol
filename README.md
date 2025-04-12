# SOL - Steves Odin Library

This is a small collection of code I wrote, that I think might
be useful for others as well.

**WARNING: I do not consider all parts of this stable or finished. Especially the iterator stuff needs some polish.**

- _**What works:** The expression evaluator, the fixed dynamic array, iterators and the stack tracking allocator should be ready._
- _**What probably works:** The opaque stuff should work as well, but as its quite low level, there might be hidden bugs that will be hard to track down. Use at your own risk._
- _**What you shouldn't use:** Everything inside the experiments folder. Currently there is only the slice abuse, but that relies on implementation details and could break with every compiler update._

<!-- omit in toc -->
## Table of contents
- [History aka why this exists](#history-aka-why-this-exists)
- [Types](#types)
  - [Opaque](#opaque)
    - [Variants](#variants)
      - [OpaqueInline](#opaqueinline)
      - [OpaqueBoxed](#opaqueboxed)
      - [OpaquePtr](#opaqueptr)
    - [When to use which opaque type](#when-to-use-which-opaque-type)
  - [Iter](#iter)
  - [Fixed Dynamic Array](#fixed-dynamic-array)
    - [Fixed Dynamic Array / Iter](#fixed-dynamic-array--iter)
  - [Expression Evaluator](#expression-evaluator)
  - [Stack Tracking Allocator](#stack-tracking-allocator)

## History aka why this exists

This is a collection of things I implemented for the game I'm working on,
which I decided to publish, because others might find it useful as well.

For a deep-dive on how each part came to be, you can check out
[my blog](https://blog.hardliner.codes/posts/01-my-odin-library)
and read about it there.

## Types
### Opaque
Adds opaque types that can be used to store or pass data with its type erased.

**WARNING: This code transmutes. Use at your own risk.**

#### Variants
##### OpaqueInline
OpaqueInline stores the data internally as a statically sized byte array.

This makes it the simplest opaque type to use, but it comes with a few restrictions.

1) **It needs to know the maximum size you will store inside at compile time**

If you can only dynamically determine what the size is, this type wont work.
However, you can use the `make_opaque_sized` function, which takes an additional size argument,
and specify a size thats big enough to hold all instances that you might want.

2) **You shouldn't store pointers to the opaque type itself or the type stored inside**

The whole type lives on the stack and copies the bytes of the type it stores into its
internal storage. This means that if the opaque goes out of scope, any pointer to it
or its data is going to be invalid. The upside is, that you don't need to manually free anything.

3) **It can't store arbitrarily big datatypes**

As the whole thing lives on the stack, you cannot store more data than the stack holds.

##### OpaqueBoxed
OpaqueBoxed stores the data internally as a slice of bytes, which gets allocated on creation.
It also stores which allocator was used, so it can use the same allocator when it gets destroyed.

This means it can store arbitrarily big data types and pointers to its internal data stay
valid until it is destroyed.

The biggest drawback is, that you need to call `destroy_boxed_opaque` on it when you're done,
otherwise it will leak its memory.

##### OpaquePtr
This is the simplest of the opaque types, yet it can be quite tricky to use.
Instead of storing the data directly, it takes a pointer and stores it as a rawptr (void* in c).

This means that its your job to guarantee that the data it points to stays valid while the
OpaquePtr is in use.

#### When to use which opaque type

If the data is already on the heap and you just need to store a reference in an untyped manner,
use an `OpaquePtr`.

If you want to store data in a way that does not allocate or does not need an accompaniying destroy call
use an `OpaqueInline`.

In any other case use an `OpaqueBoxed`.

### Iter
The iter package defines an interface for iterators,
which can be implemented to allow functions to take a generic iterator,
without knowing exactly how it works underneath.

### Fixed Dynamic Array
The name might seem like it contradicts itself,
but I couldn't think of a better one, so it has to do for now.

Its the same concept as [Small_Array](https://pkg.odin-lang.org/core/container/small_array/),
but uses heap allocated memory internally.
This makes it possible to decide the size at runtime,
while still having a static block of memory,
combined with the interface of a dynamic array.

_So append away and don't worry about keeping track where to put the next element!_

#### Fixed Dynamic Array / Iter
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

### Expression Evaluator
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

### Stack Tracking Allocator
This is basically the tracking allocator from the stdlib,
but it stores a stack trace for the allocation as well.

This way you not only know where the allocation was made,
but also what the call history was.