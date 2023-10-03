---
paginate: true
---

<!--
Hello

I'm here to present a feature in Typescript 5.2: explicit resource management
with `using`
-->

# ECMA Explicit Resource Management

## `using` and `await using`

Presented by Eric Bower (https://bower.sh)

---

<!--
Let's jump right into some code so we have a rough idea of the problem and
proposed solution.

Here's a synchronous example where we acquire a file handler and it
automatically gets released when the function is done executing.
-->

# Example

```js
// sync disposal
function* g() {
  using handle = acquireFileHandle(); // block-scoped critical resource
} // cleanup

{
  using obj = g(); // block-scoped declaration
  const r = obj.next();
} // calls finally blocks in `g`
```

---

# Async Example

```ts
// async disposal
async function * g() {
  using stream = acquireStream(); // block-scoped critical resource
  ...
} // cleanup

{
  await using obj = g(); // block-scoped declaration
  const r = await obj.next();
} // calls finally blocks in `g`
```

---

# Primary Sources

- TC39 Proposal[^1]
- Typescript 5.2 Release Notes[^2]

---

# ECMA Status

- Stage: 3
- Champion: Ron Buckton (@rbuckton)
- Last Presented: March, 2023 (slides[^3], notes #1[^4], notes #2[^5])

---

# Motivation

<!--
Before talking about the solution ECMA and TS came up with, I figured we should
talk about the problem space.
-->

- Inconsistent patterns for resource management:
  - ECMAScript Iterators: `iterator.return()`
  - WHATWG Stream Readers: `reader.releaseLock()`
  - NodeJS FileHandles: `handle.close()`
  - Emscripten C++ objects handles:
    `Module._free(ptr) obj.delete() Module.destroy(obj)`
- Avoiding common footguns when managing resources
- Scoping resources
- Avoiding common footguns when managing multiple resources
- Avoiding lengthy code when managing multiple resources correctly
- Non-blocking memory/IO applications

---

# Avoiding common footguns when managing resources

```js
const reader = stream.getReader();
...
reader.releaseLock(); // Oops, should have been in a try/finally
```

---

# Scoping resources

```js
const handle = ...;
try {
  ... // ok to use `handle`
}
finally {
  handle.close();
}
// not ok to use `handle`, but still in scope
```

---

# Avoiding common footguns when managing multiple resources

```js
const a = ...;
const b = ...;
try {
  ...
}
finally {
  a.close(); // Oops, issue if `b.close()` depends on `a`.
  b.close(); // Oops, `b` never reached if `a.close()` throws.
}
```

---

# Prior Art

<!--
Explicit resource management as a language concept exists in other languages.

I'm most familiar with this concept in Python.
-->

- C#:
  - `using` statement[^6]
  - `using` declaration[^7]
- Java: `try`-with-resources statement[^8]
- Python: `with` statement[^9]

---

# Python Example

```python
with open("romeo.txt", "r") as file:
  data = file.read()
  print("The file contents are:")
  print(data)
# file.close() implicitly called after block
```

---

# `Symbol.dispose`

<!--
Part of this feature is making it possible for end-developers to provide a
method on their JS objects that can automatically be called when we want to
remove resources.
-->

```ts
function loggy(id: string): Disposable {
  console.log(`Creating ${id}`);
  return {
    [Symbol.dispose]() {
      console.log(`Disposing ${id}`);
    },
  };
}

function func() {
  using a = loggy("a");
  using b = loggy("b");
}

func();
// Creating a
// Creating b

// Disposing b
// Disposing a
```

---

# `Symbol.asyncDispose`

```ts
async function doWork() {
  // Do fake work for half a second.
  await new Promise((resolve) => setTimeout(resolve, 500));
}

function loggy(id: string): AsyncDisposable {
  console.log(`Constructing ${id}`);

  return {
    async [Symbol.asyncDispose]() {
      console.log(`Disposing (async) ${id}`);
      await doWork();
    },
  };
}
```

---

# Other well-known `Symbol`s

<!--
These are static properties on the global `Symbol` object.
-->

- `Symbol.asyncIterator`
- `Symbol.hasInstance`
- `Symbol.isConcatSpeadable`
- `Symbol.iterator`
- `Symbol.match`
- `Symbol.matchAll`
- `Symbol.replace`
- `Symbol.search`
- `Symbol.species`
- `Symbol.split`
- `Symbol.toPrimitive`
- `Symbol.toStringTag`
- `Symbol.unscopables`

# `DisposableStack`

<!--
This feature also introduces a couple of new global classes you can instantiate
to manage many resources at the same time.
-->

- Useful for doing one-off and arbitrary amounts of clean-up
- A `DisposableStack` is an object that has several methods for keeping track of
  `Disposable` objects
- Can be given functions for doing arbitrary clean-up work
- We can also assign them to `using` variables because -- get this -- they’re
  also `Disposable`!

---

# `DisposableStack` Example

```ts
function doSomeWork() {
  const path = ".some_temp_file";
  const file = fs.openSync(path, "w+");

  using cleanup = new DisposableStack();
  cleanup.defer(() => {
    fs.closeSync(file);
    fs.unlinkSync(path);
  });

  // use file...
  if (someCondition()) {
    // do some more work...
    return;
  }
  // ...
}
```

---

# `using` it today!

<!--
- Needs TS 5.2
- Need polyfills for the browser
-->

Because this feature is so recent, most runtimes will not support it natively.
To use it, you will need runtime polyfills for the following:

- `Symbol.dispose`
- `Symbol.asyncDispose`
- `DisposableStack`
- `AsyncDisposableStack`
- `SuppressedError`

---

However, if you only want `using` and `await using`, something as simple as the
following should work for most cases:

```ts
Symbol.dispose ??= Symbol("Symbol.dispose");
Symbol.asyncDispose ??= Symbol("Symbol.asyncDispose");
```

You will also need the following in `tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "es2022",
    "lib": ["es2022", "esnext.disposable", "dom"]
  }
}
```

---

# fin

[^1]: https://github.com/tc39/proposal-explicit-resource-management
[^2]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-2.html
[^3]: https://1drv.ms/p/s!AjgWTO11Fk-Tkodu1RydtKh2ZVafxA?e=yasS3Y
[^4]: https://github.com/tc39/notes/blob/main/meetings/2023-03/mar-21.md#async-explicit-resource-management
[^5]: https://github.com/tc39/notes/blob/main/meetings/2023-03/mar-23.md#async-explicit-resource-management-again
[^6]: https://docs.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/using-statement
[^7]: https://docs.microsoft.com/en-us/dotnet/csharp/language-reference/proposals/csharp-8.0/using#using-declaration
[^8]: https://docs.oracle.com/javase/tutorial/essential/exceptions/tryResourceClose.html
[^9]: https://docs.python.org/3/reference/compound_stmts.html#the-with-statement
