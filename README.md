# Gleam Tours

Tours through various topics in Gleam.

## Notes

## Nominal types differ if loaded twice

When using `import` with generated js code any classes defined within are new. 
Therefore calling functions from that imported module cannot be custom types i.e. a `Response`.

If you do you will get a confusing bug where printing the value will near what is expected but starting with `//js`.

The solution is to either:
1. Pass in plain data, i.e. JSON
2. Make sure that all custom types are loaded from the same import path.

Option 1 requires any parsing code is in the correct environment either in the gleamtours application or in the loaded guide code.
The `wrap__` module is used to parse request types.
Option 2 is potentially fragile and requires page reloads if some source files have changed.
It also prevents the use of bundling the gleamtours application code as anything shared needs to be at the same import path for compiled code.

## Code from the same path is only ever imported once

Using `import("./mycode.mjs")` will always return the same value (before reloading a page).
Using service workers to intercept this request and serve newly compiled code will not work after the first import.

The solutions is to either:
1. Add a unique idendifier to the path `import("./0/mycode.mjs")`.
2. Run the import code in an iframe, or other window that can be reloaded to trigger new imports.

Option 1 is possible because all gleam modules are compiled to have relative imports. However a uniwue path makes nominal types different on each load.

## A service worker must call `respondWith` synchronously

For a service worker to handle a users request it must call [`respondWith`](https://developer.mozilla.org/en-US/docs/Web/API/FetchEvent/respondWith) synchronously.
The argument to this call can be a promise if the response is not yet known.
However that promise MUST resolve, not returning or erroring will not cause the request to return to being handled by the network.

## Dynamic import is not available in service workers

https://github.com/w3c/ServiceWorker/issues/1356

This is to make sure that service workers work offline, with `import` they may try and use resources that are still over the network.
There is [`importScripts`](https://developer.mozilla.org/en-US/docs/Web/API/WorkerGlobalScope/importScripts) that service workers can use to import scripts, but only at startup time.

Therefore to use the import method of handling dyamic gleam modules the requests must be forwarded to a window or worker.
Works can use imports but not the need to be created with type "module".

## `global.onMessage` doesn't receive messages from service worker.

I'm not the only one confused about this https://github.com/w3c/ServiceWorker/issues/609, https://web.dev/articles/two-way-communication-guide

instead use `navigator.serviceWorker.onmessage`

## A service worker scope may not affect the page that installed it.

A service worker installed at `./sandbox/sw.js` with only effect fetches FROM scripts with an origin under `./sandbox/*`.
If the script installing this worker is at `./index.js` then ANY fetch requests, including `./sandbox/foo.js` will ignore the service worker.

Only by opening a window under `./sandbox/index.html` or importing a script under that scope will you start intercepting.
This can also cause a change in behaviour when using a bundler, as the code that was in a scope module will be lifted into the bundle.

Awaiting on the promise from a register function only checks that the service worker will be used in the future.
The `navigator.serviceWorker.ready` can be used to check that the controlling registration is active.
`navigator.serviceWorker.controller == registration.active` only when scope includes the page and has become active.
