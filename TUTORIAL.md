Poodinis Tutorial
=================
This tutorial will give you an overview of all functionality offered by Poodinis and how to use them.

The container
-------------
To register a class, a new dependency container must be instantiated:
```d
// Create a shared container
auto dependencies = new shared DependencyContainer();
```
A shared dependency container is thread-safe and resolves the same dependencies across all threads.
###Registering dependencies
To make dependencies available, they have to be registered:
```d
// Register concrete class
dependencies.register!ExampleClass;
// Register by super type
dependencies.register!(ExampleInterface, ExampleClass);
```
In the above example, dependencies on the concrete class and interface will resolve an instance of class `ExampleClass`. A dependency registered by super type will automatically be registered by concrete type.

If you want to prevent registrations from being both registered by interface and concrete type, use the `doNotAddConcreteTypeRegistration` option when registering:
```d
dependencies.register!(ExampleInterface, ExampleClass)([RegistrationOption.doNotAddConcreteTypeRegistration]);
```

Resolving dependencies
----------------------
To manually resolve a dependency, all you have to do is resolve the dependency's type using the container in which it is registered:
```d
auto exampleClassInstance = dependencies.resolve!ExampleClass;
```
If the class is registered by interface and not by concrete type, you can still resolve the class by concrete type (unless `doNotAddConcreteTypeRegistration` is applied):

```d
auto exampleClassInstance = dependencies.resolve!ExampleInterface;
auto exampleClassInstance2 = dependencies.resolve!ExampleClass;
assert(exampleClassInstance is exampleClassInstance2);
```

It is also possible to register a type while resolving it. Doing so means you don't need to explicitly register it beforehand. To do this, use the resolve option `registerBeforeResolving`:
```d
dependencies.resolve!ExampleClass([ResolveOption.registerBeforeResolving]);
```
Naturally this can only be done when you are resolving a concrete type or an interface type by qualifier.

Dependency creation behaviour
-----------------
You can control how a dependency is resolved by specifying a creation scope during registration. The scope determines which instance is returned, be it the same each time or a new one. The following scopes are available:

* Resolve a dependency using a single instance (default):

```d
dependencies.register!ExampleClass.singleInstance();
```
* Resolve a dependency with a new instance each time it is resolved:

```d
dependencies.register!ExampleClass.newInstance();
```
* Resolve a dependency using a pre-existing instance

```d
auto preExistingInstance = new ExampleClass();
dependencies.register!ExampleClass.existingInstance(preExistingInstance);
```

Automatic Injection
----------
The real value of any dependency injection framework comes from its ability to automatically inject dependencies. Poodinis supports automatic injection either through autowiring members annotated with the `@Autowire` UDA or through constructor injection.
### UDA-based autowiring
UDA-based autowiring can be achieved by annotating members of a class with the `@Autowire` UDA:
```d
class ExampleClassA {}

class ExampleClassB {
	@Autowire
	private ExampleClassA dependency;
}

dependencies.register!ExampleClassA;
auto exampleInstance = new ExampleClassB();
dependencies.autowire(exampleInstance);
assert(exampleInstance.dependency !is null);
```
It is possible to autowire public as well as protected and private members.

Dependencies are automatically autowired when a class is resolved. So when you resolve `ExampleClassB`, its member `dependency` is automatically autowired:
```d
dependencies.register!ExampleClassA;
dependencies.register!ExampleClassB;
auto instance = dependencies.resolve!ExampleClassB;
assert(instance.dependency !is null);
```
If an interface is to be autowired, you must register a concrete class by interface. A class registered only by concrete type can only be injected into members of that type, not its supertypes.

Using the UDA `OptionalDependency` you can mark an autowired member as being optional. When a member is optional, no ResolveException will be thrown when
the type of the member is not registered and `ResolveOption.registerBeforeResolving` is not set on the container. The member will remain null or an empty array in
case of array dependencies.
```d
class ExampleClass {
	@Autowire
	@OptionalDependency
	private AnotherExampleClass dependency;
}
```

### Constructor injection
Poodinis also supports automatic injection of dependencies through constructors:
```d
class ExampleClassA {}

class ExampleClassB {
	private ExampleClassA dependency;

	this(ExampleClassA dependency) {
		this.dependency = dependency;
	}
}

dependencies.register!ExampleClassA;
dependencies.register!ExampleClassB;

auto instance = dependencies.resolve!ExampleClassB;
 
```
`ExampleClassA` is automatically resolved and passed to `ExampleClassB`'s constructor. 
Classes with multiple constructors can be injected. The following rules apply to constructor injection:
* Injection is attempted at the order of declaration. However, this is compiler dependant and may not always be the case.
* Injection is attempted for the first constructor which has non-builtin types only in its parameter list.
* When a constructor with an empty parameter list is found, no other constructors are attempted (and nothing is injected). This can be used to explicitly prevent constructor injection.
* When no injectable constructor is found an InstanceCreationException will be thrown on resolve.

If the constructors of a class are not suitable for injection, you could manually configure its creation using Application Contexts (see chapter further down).  
Constructor injection has the advantage of not having to import Poodinis throughout your application.

Circular dependencies
---------------------
Poodinis can autowire circular dependencies when they are registered with `singleInstance` or `existingInstance` registration scopes. Circular dependencies in registrations with `newInstance` scopes will not be autowired, as this would cause an endless loop. Circular dependencies are only supported when autowiring members through the `@Autowire` UDA; circular dependencies in constructors are not supported and will result in an `InstanceCreationException`.

Registering and resolving using qualifiers
------------------------------------------
You can register multiple concrete types to a super type. When doing so, you will need to specify a qualifier when resolving that type:
```d
// Color is an interface, Blue and Red are classes implementing that interface
dependencies.register!(Color, Blue);
dependencies.register!(Color, Red);
auto blueInstance = dependencies.resolve!(Color, Blue);
```
If you want to autowire a type registered to multiple concrete types, specify a qualified type as template argument:
```d
class BluePaint {
	@Autowire!Blue
	private Color color;
}
```
If you registered multiple concrete types to the same supertype and you do not resolve using a qualifier, a `ResolveException` is thrown stating that there are multiple candidates for the type to be resolved.

Autowiring all registered instances to an array
-----------------------------------------------
If you have registered multiple concrete types to a super type, you can autowire them all to an array, in which case you can easily operate on them all:
```d
// Color is an interface, Blue and Red are classes implementing that interface

class ColorMixer {
	@Autowire
	private Color[] colors;
}

dependencies.register!(Color, Blue);
dependencies.register!(Color, Red);
auto mixer = dependencies.resolve!ColorMixer;
```
Member `mixer.colors` will now contain instances of `Blue` and `Red`. The order in which instances are resolved is not guaranteed to be that of the order in which they were registered.

Application Contexts
--------------------
You can fine-tune dependency configuration using application contexts. Application contexts allow you to centralize all dependency configuration as well as define how instances of certain classes should be constructed using factory methods.

###Defining and using application contexts
An application context is defined as follows:
```d
class Context : ApplicationContext {
	public override void registerDependencies(shared(DependencyContainer) container) {
		container.register!SomeClass;
		container.register!(SomeInterface, SomeOtherClass).newInstance();
	}
	
	@Component
	public SomeLibraryClass libraryClass() {
		return new SomeLibraryClass("This class uses a constructor parameter of a built-in type so I have to register it through an application context");
	}
}
```
In the override `registerDependencies()` you can register all dependencies which do not need complex set-up, just like you would do when directly using the dependency container. 
This override is optional. You can still register simple dependencies outside of the context (or in another context).  
Complex dependencies are registered through member methods of the context. These member methods serve as factory methods which will be called when a dependency is resolved. 
They are annotated with the `@Component` UDA to let the container know that these methods should be registered as dependencies. The type of the registration is the same as the return type of the method.  
Factory methods are useful when you have to deal with dependencies which require constructor arguments or elaborate set-up after instantiation.  
Application contexts have to be registered with a dependency container. They are registered as follows:
```d
container.registerContext!Context;
```
All registered dependencies can now be resolved by the same dependency container. Registering a context will also register it as a dependency, meaning you can autowire the application context in other classes. 
You can register as many types of application contexts as you like.

###Autowiring application contexts
Application contexts can make use of autowired dependencies like any other dependency. When registering an application context, all its components are registered first after which the application context is autowired. 
This means that after the registration of an application context some dependencies will already be resolved and instantiated. The following example illustrates how autowired members can be used in a context:
```d
class Context : ApplicationContext {

	@Autowire
	private SomeClass someClass;
	
	@Autowire
	private SomeOtherClass someOtherClass;

	public override void registerDependencies(shared(DependencyContainer) container) {
		container.register!SomeClass;
	}
	
	@Component
	public SomeLibraryClass libraryClass() {
		return new SomeLibraryClass(someClass, someOtherClass);
	}
}
```
As you can see, autowired dependencies can be used within factory methods. When `SomeLibraryClass` is resolved, it will be created with a resolved instance of `SomeClass` and `SomeOtherClass`. As shown, autowired dependencies can be registered within the same
application context, but don't neccesarily have to be. You can even autowire dependencies which are created within a factory method within the same application context.  
Application contexts are directly autowired after they have been registered. This means that all autowired dependencies which are not registered in the application context itself need to be registered before registering the application context.

###Controlling component registration
You can further influence how components are registered and created with additional UDAs:
```d
class Context : ApplicationContext {
	@Component
	@Prototype // Will create a new instance every time the dependency is resolved.
	@RegisterByType!SomeInterface // Registers the dependency by the specified super type instead of the return type
	public SomeClass someClass() {
		return new SomeClass();
	}
}
```

Persistent Registration and Resolve Options
-------------------------------
If you want registration options to be persistent (applicable for every call to `register()`), you can use the container method `setPersistentRegistrationOptions()`:
```d
dependencies.setPersistentRegistrationOptions(RegistrationOption.doNotAddConcreteTypeRegistration); // Sets the options
dependencies.unsetPersistentRegistrationOptions(); // Clears the persistentent options
```
Likewise, the same is possible for resolve options:
```d
dependencies.setPersistentResolveOptions(ResolveOption.registerBeforeResolving); // Sets the options
dependencies.unsetPersistentResolveOptions(); // Clears the persistentent options
```
Please note that setting options will unset previously set options; the options specified will be the only ones in effect.