/**
 * This module contains objects for defining and scoping dependency registrations.
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

module poodinis.registration;

import poodinis.container;
import poodinis.factory;

class Registration {
	private TypeInfo _registeredType = null;
	private TypeInfo_Class _instanceType = null;
	private Registration linkedRegistration;
	private shared(DependencyContainer) _originatingContainer;
	private InstanceFactory _instanceFactory;

	public @property registeredType() {
		return _registeredType;
	}

	public @property instanceType() {
		return _instanceType;
	}

	public @property originatingContainer() {
		return _originatingContainer;
	}

	public @property instanceFactory() {
		return _instanceFactory;
	}

	this(TypeInfo registeredType, TypeInfo_Class instanceType, InstanceFactory instanceFactory, shared(DependencyContainer) originatingContainer) {
		this._registeredType = registeredType;
		this._instanceType = instanceType;
		this._originatingContainer = originatingContainer;
		this._instanceFactory = instanceFactory;
	}

	public Object getInstance(InstantiationContext context = new InstantiationContext()) {
		if (linkedRegistration !is null) {
			return linkedRegistration.getInstance(context);
		}


		if (instanceFactory is null) {
			throw new InstanceCreationException("No instance factory defined for registration of type " ~ registeredType.toString());
		}

		return instanceFactory.getInstance();
	}

	public Registration linkTo(Registration registration) {
		this.linkedRegistration = registration;
		return this;
	}
}

/**
 * Scopes registrations to return the same instance every time a given registration is resolved.
 *
 * Effectively makes the given registration a singleton.
 */
public Registration singleInstance(Registration registration) {
	registration.instanceFactory.factoryParameters = InstanceFactoryParameters(registration.instanceType, CreatesSingleton.yes);
	return registration;
}

/**
 * Scopes registrations to return a new instance every time the given registration is resolved.
 */
public Registration newInstance(Registration registration) {
	registration.instanceFactory.factoryParameters = InstanceFactoryParameters(registration.instanceType, CreatesSingleton.no);
	return registration;
}

/**
 * Scopes registrations to return the given instance every time the given registration is resolved.
 */
public Registration existingInstance(Registration registration, Object instance) {
	registration.instanceFactory.factoryParameters = InstanceFactoryParameters(registration.instanceType, CreatesSingleton.yes, instance);
	return registration;
}

public string toConcreteTypeListString(Registration[] registrations) {
	auto concreteTypeListString = "";
	foreach (registration ; registrations) {
		if (concreteTypeListString.length > 0) {
			concreteTypeListString ~= ", ";
		}
		concreteTypeListString ~= registration.instanceType.toString();
	}
	return concreteTypeListString;
}

class InstantiationContext {}
