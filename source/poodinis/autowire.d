/**
 * Contains functionality for autowiring dependencies using a dependency container.
 *
 * This module is used in a dependency container for autowiring dependencies when resolving them.
 * You typically only need this module if you want inject dependencies into a class instance not
 * managed by a dependency container.
 *
 * Part of the Poodinis Dependency Injection framework.
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2016 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE file.
 */

module poodinis.autowire;

import poodinis.container;
import poodinis.registration;
import poodinis.factory;

import std.exception;
import std.stdio;
import std.string;
import std.traits;
import std.range;

struct UseMemberType {};

/**
 * UDA for annotating class members as candidates for autowiring.
 *
 * Optionally a template parameter can be supplied to specify the type of a qualified class. The qualified type
 * of a concrete class is used to autowire members declared by supertype. If no qualifier is supplied, the type
 * of the member is used as qualifier.
 *
 * Examples:
 * Annotate member of class to be autowired:
 * ---
 * class Car {
 *    @Autowire
 *    public Engine engine;
 * }
 * ---
 *
 * Annotate member of class with qualifier:
 * ---
 * class FuelEngine : Engine { ... }
 * class ElectricEngine : Engine { ... }
 *
 * class HybridCar {
 *    @Autowire!FuelEngine
 *    public Engine fuelEngine;
 *
 *    @Autowire!ElectricEngine
 *    public Engine electricEngine;
 * }
 * ---
 * The members of an instance of "HybridCar" will now be autowired properly, because the autowire mechanism will
 * autowire member "fuelEngine" as if it's of type "FuelEngine". This means that the members of instance "fuelEngine"
 * will also be autowired because the autowire mechanism knows that member "fuelEngine" is an instance of "FuelEngine"
 */
struct Autowire(QualifierType = UseMemberType) {
	QualifierType qualifier;
};


/**
 * UDA for marking autowired dependencies optional.
 * Optional dependencies will not lead to a resolveException when there is no type registered for them.
 * The member will remain null.
 */
struct OptionalDependency {};

/**
 * UDA for annotating class members to be autowired with a new instance regardless of their registration scope.
 *
 * Examples:
 *---
 * class Car {
 *     @Autowire
 *     @AssignNewInstance
 *     public Antenna antenna;
 * }
 *---
 * antenna will always be assigned a new instance of class Antenna.
 */
struct AssignNewInstance {}

private void printDebugAutowiredInstance(TypeInfo instanceType, void* instanceAddress) {
	writeln(format("DEBUG: Autowiring members of [%s@%s]", instanceType, instanceAddress));
}

/**
 * Autowires members of a given instance using dependencies registered in the given container.
 *
 * All public members of the given instance, which are annotated using the "Autowire" UDA, are autowired.
 * All members are resolved using the given container. Qualifiers are used to determine the type of class to
 * resolve for any member of instance.
 *
 * Note that private members will not be autowired because the autowiring mechanism is not able to by-pass
 * member visibility protection.
 *
 * See_Also: Autowire
 */
public void autowire(Type)(shared(DependencyContainer) container, Type instance) {
	debug(poodinisVerbose) {
		printDebugAutowiredInstance(typeid(Type), &instance);
	}

	// note: recurse into base class if there are more between Type and Object in the hirarchy
	static if(BaseClassesTuple!Type.length > 1)
	{
		autowire!(BaseClassesTuple!Type[0])(container, instance);
	}

	foreach(index, name; FieldNameTuple!Type) {
		autowireMember!(name, index, Type)(container, instance);
	}
}

private void printDebugAutowiringCandidate(TypeInfo candidateInstanceType, void* candidateInstanceAddress, TypeInfo instanceType, void* instanceAddress, string member) {
	writeln(format("DEBUG: Autowired instance [%s@%s] to [%s@%s].%s", candidateInstanceType, candidateInstanceAddress, instanceType, instanceAddress, member));
}

private void printDebugAutowiringArray(TypeInfo superTypeInfo, TypeInfo instanceType, void* instanceAddress, string member) {
	writeln(format("DEBUG: Autowired all registered instances of super type %s to [%s@%s].%s", superTypeInfo, instanceType, instanceAddress, member));
}

private void autowireMember(string member, size_t memberIndex, Type)(shared(DependencyContainer) container, Type instance) {
	foreach(autowireAttribute; __traits(getAttributes, Type.tupleof[memberIndex])) {
		static if (__traits(isSame, autowireAttribute, Autowire) || is(autowireAttribute == Autowire!T, T)) {
			if (instance.tupleof[memberIndex] is null) {
				alias MemberType = typeof(Type.tupleof[memberIndex]);

				enum assignNewInstance = hasUDA!(Type.tupleof[memberIndex], AssignNewInstance);
				enum isOptional = hasUDA!(Type.tupleof[memberIndex], OptionalDependency);

				static if (isDynamicArray!MemberType) {
					alias MemberElementType = ElementType!MemberType;
					static if (isOptional) {
						auto instances = container.resolveAll!MemberElementType(ResolveOption.noResolveException);
					} else {
						auto instances = container.resolveAll!MemberElementType;
					}
					instance.tupleof[memberIndex] = instances;
					debug(poodinisVerbose) {
						printDebugAutowiringArray(typeid(MemberElementType), typeid(Type), &instance, member);
					}
				} else {
					debug(poodinisVerbose) {
						TypeInfo qualifiedInstanceType = typeid(MemberType);
					}

					MemberType qualifiedInstance;
					static if (is(autowireAttribute == Autowire!T, T) && !is(autowireAttribute.qualifier == UseMemberType)) {
						alias QualifierType = typeof(autowireAttribute.qualifier);
						qualifiedInstance = createOrResolveInstance!(MemberType, QualifierType, assignNewInstance, isOptional)(container);
						debug(poodinisVerbose) {
							qualifiedInstanceType = typeid(QualifierType);
						}
					} else {
						qualifiedInstance = createOrResolveInstance!(MemberType, MemberType, assignNewInstance, isOptional)(container);
					}

					instance.tupleof[memberIndex] = qualifiedInstance;

					debug(poodinisVerbose) {
						printDebugAutowiringCandidate(qualifiedInstanceType, &qualifiedInstance, typeid(Type), &instance, member);
					}
				}
			}

			break;
		}
	}
}

private QualifierType createOrResolveInstance(MemberType, QualifierType, bool createNew, bool isOptional)(shared(DependencyContainer) container) {
	static if (createNew) {
		auto instanceFactory = new InstanceFactory();
		instanceFactory.factoryParameters = InstanceFactoryParameters(typeid(MemberType), CreatesSingleton.no);
		return cast(MemberType) instanceFactory.getInstance();
	} else {
		static if (isOptional) {
			return container.resolve!(MemberType, QualifierType)(ResolveOption.noResolveException);
		} else {
			return container.resolve!(MemberType, QualifierType);
		}
	}
}

/**
 * Autowire the given instance using the globally available dependency container.
 *
 * See_Also: DependencyContainer
 * Deprecated: Using the global container is undesired. See DependencyContainer.getInstance().
 */
public deprecated void globalAutowire(Type)(Type instance) {
	DependencyContainer.getInstance().autowire(instance);
}

class AutowiredRegistration(RegistrationType : Object) : Registration {
	private shared(DependencyContainer) container;

	public this(TypeInfo registeredType, InstanceFactory instanceFactory, shared(DependencyContainer) originatingContainer) {
		super(registeredType, typeid(RegistrationType), instanceFactory, originatingContainer);
	}

	public override Object getInstance(InstantiationContext context = new AutowireInstantiationContext()) {
		enforce(!(originatingContainer is null), "The registration's originating container is null. There is no way to resolve autowire dependencies.");

		RegistrationType instance = cast(RegistrationType) super.getInstance(context);

		AutowireInstantiationContext autowireContext = cast(AutowireInstantiationContext) context;
		enforce(!(autowireContext is null), "Given instantiation context type could not be cast to an AutowireInstantiationContext. If you relied on using the default assigned context: make sure you're calling getInstance() on an instance of type AutowiredRegistration!");
		if (autowireContext.autowireInstance) {
			originatingContainer.autowire(instance);
		}

		return instance;
	}

}

class AutowireInstantiationContext : InstantiationContext {
	public bool autowireInstance = true;
}
