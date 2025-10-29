# Compiler
The compiler adds a lot of resources

## macros

fn invert(node: Node)
	ret new BinOp(node.right, node.left)
end

invert(4 / 8);

## Decorator
With macro:
```
fn entity(node: Node) -> Node
	const obj = new ObjDecl(
		node
	)

	ret new ConDecl(new Id("entity"), obj);
end

@entity
fn myFunc()

end

# con entity = {
# 	 fn myFunc()
#
#	 end
# }
```
## inline

```
inline for ()

end

inline fn a ()

end
```

## Declare
```
decl con a: num
decl con b: str
decl con c: obj
decl con d: arr<num>
```

```
struct Dog
	fn()

	end

	fn commonPrivate()
	end

	pub fn communPublic()
	end

	@call fn(...args)
	end

	@access fn(prop: str)

	end

	@str fn()

	end

	@index fn(i: num)

	end

	@static fn myStatic()

	end

	@plus fn()

	end

	@minus

	end

	@slash fn()

	end

	@asterisk fn()

	end
end

const dog = new Dog()

dog / dog

```

```
enum