/**
 * Contains the implementation of application context setup.
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

module poodinis.context;

import poodinis.container;
import poodinis.registration;
import poodinis.factory;

import std.traits;

class ApplicationContext {
	public void registerDependencies(shared(DependencyContainer) container) {}
}

/**
* A component annotation is used for specifying which factory methods produce components in
* an application context.
*/
struct Component {}

/**
* This annotation allows you to specify by which super type the component should be registered. This
* enables you to use type-qualified alternatives for dependencies.
*/
struct RegisterByType(Type) {
	Type type;
}

/**
* Components with the prototype registration will be scoped as dependencies which will create
* new instances every time they are resolved. The factory method will be called repeatedly.
*/
struct Prototype {}

public void registerContextComponents(ApplicationContextType : ApplicationContext)(ApplicationContextType context, shared(DependencyContainer) container) {
	foreach (member ; __traits(allMembers, ApplicationContextType)) {
		static if (__traits(getProtection, __traits(getMember, context, member)) == "public" && hasUDA!(__traits(getMember, context, member), Component)) {
			auto factoryMethod = &__traits(getMember, context, member);
			Registration registration = null;
			auto createsSingleton = CreatesSingleton.yes;

			foreach(attribute; __traits(getAttributes, __traits(getMember, context, member))) {
				static if (is(attribute == RegisterByType!T, T)) {
					registration = container.register!(typeof(attribute.type), ReturnType!factoryMethod);
				} else static if (__traits(isSame, attribute, Prototype)) {
					createsSingleton = CreatesSingleton.no;
				}
			}

			if (registration is null) {
				registration = container.register!(ReturnType!factoryMethod);
			}

			registration.instanceFactory.factoryParameters = InstanceFactoryParameters(registration.instanceType, createsSingleton, null, factoryMethod);
		}
	}
}
