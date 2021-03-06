# webworker-proxy

A Haxe macro for generating a Web Worker proxy.

## Limitations

- Static methods _are not_ proxied.
- See [target limitations below](#target-limitations) for more information.

## Installation

### Using [lix-pm](https://github.com/lix-pm/lix.client#readme)

`lix install gh:skial/webworker-proxy`

### Using [HaxeLib](https://lib.haxe.org/documentation/using-haxelib/#git)

`haxelib git webworker-proxy https://github.com/skial/webworker-proxy.git`

---

Add `-lib webworker-proxy` once you've added webworker-proxy as a dependancy.

## Defines

- `-D webworker`
- `-D wwp-debug` Will print out what the various macro's are generating.
- `-D wwp-disable-check` Prevents `Transferable<Type>` from checking the `Type` can be transferred.

## Usage

See [`test/Entry.hx`](https://github.com/skial/webworker-proxy/blob/master/test/Entry.hx) for an alternative example.

### `Main.hx`
```Haxe
package ;

class Foo extends WorkerChannel {
    public function new() {}

    public function echoChamber(v:String) return '$v {} $v';
}

class Main {
    public static function main() {
        var proxy = new WorkerProxy<Foo>(
            #if !webworker
            new js.html.Worker('ww.js')
            #else
            new Foo()
            #end
        );
        proxy
            .echoChamber( 'hello world' ) // returns tink.CoreApi.Promise<String>
            .handle( o -> switch o {
                case Success(v): trace( v );
                case Failure(e): trace( e );
            } );
    }
}
```

### `build.hxml`
```
-lib webworker-proxy
-main Main

--each

-js bin/main.js

--next

-D webworker
-js bin/ww.js
```

## Target Limitations

### JavaScript

- See [supported types](https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API/Structured_clone_algorithm#Supported_types).
- Values are transfered between main and worker threads using the [structure clone algorithm](https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API/Structured_clone_algorithm) implemented by browsers.