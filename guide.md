<!-- NOTE: the file `guide.md` should not be edited.
Edit the .md files in `/docs`, and run `npm run-script generateguide`. -->

# Writing LeadConduit Integrations

This guide should tell you everything you need to know to develop LeadConduit integration modules.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->


- [1. LeadConduit Overview](#1-leadconduit-overview)
  - [What It Does](#what-it-does)
  - [How It Does It](#how-it-does-it)
- [2. Key Concepts](#2-key-concepts)
  - [Fields - Standard and Custom](#fields---standard-and-custom)
  - [Field Types](#field-types)
  - [Inbound vs. Outbound Integrations](#inbound-vs-outbound-integrations)
  - [Vars, Appended Data, and “The Snowball”](#vars-appended-data-and-the-snowball)
  - [Mapping Data](#mapping-data)
    - [Source Mapping](#source-mapping)
    - [Recipient Mapping](#recipient-mapping)
  - [Step Outcomes](#step-outcomes)
    - [Success](#success)
    - [Failure](#failure)
    - [Error](#error)
    - [Skip](#skip)
- [3. The Integration API](#3-the-integration-api)
  - [Module Introduction](#module-introduction)
  - [`index.js` & Naming](#indexjs--naming)
  - [“request and response” vs. “handle”](#request-and-response-vs-handle)
  - [`request()`](#request)
  - [`response()`](#response)
    - [`outcome`](#outcome)
    - [`reason`](#reason)
    - [`billable`](#billable)
  - [`request.variables()`](#requestvariables)
  - [`response.variables()`](#responsevariables)
  - [`handle()`](#handle)
  - [`vars`](#vars)
  - [`validate()`](#validate)
  - [`envVariables`](#envvariables)
- [4. Development Guide](#4-development-guide)
  - [Getting Started](#getting-started)
  - [Development Environment](#development-environment)
  - [Style Guide](#style-guide)
  - [Test Coverage](#test-coverage)
  - [Linting](#linting)
  - [Documentation](#documentation)
  - [Development Cycle](#development-cycle)
  - [Tips, Idioms, & Links](#tips-idioms--links)
    - [Useful references](#useful-references)
    - [Guard against null with '`?.`'](#guard-against-null-with-)
    - [Send the right types in tests](#send-the-right-types-in-tests)
    - [Look for `leadconduit-integration` functions](#look-for-leadconduit-integration-functions)
    - [Use CoffeeScript's `for…of` to iterate object properties](#use-coffeescripts-forof-to-iterate-object-properties)
    - ["Mask" sensitive data](#mask-sensitive-data)
- [5. Administration Guide](#5-administration-guide)
  - [Logging in to npm](#logging-in-to-npm)
  - [Setting up Travis CI for a new integration](#setting-up-travis-ci-for-a-new-integration)
  - [Running LeadConduit Locally](#running-leadconduit-locally)
  - [Version Numbers](#version-numbers)
  - [Cutting a Release with `cut-release`](#cutting-a-release-with-cut-release)
  - [Deploying a New or Updated Integration](#deploying-a-new-or-updated-integration)
    - [Deploying on Staging](#deploying-on-staging)
    - [Deploying on Production](#deploying-on-production)
    - [Rolling back a deploy](#rolling-back-a-deploy)
    - [Additional Setup for New Integrations](#additional-setup-for-new-integrations)
      - [Database Changes](#database-changes)
      - [Environment Variables](#environment-variables)
      - [SSO Billing Information](#sso-billing-information)
      - [User Interface Changes](#user-interface-changes)
  - [Managing Release Candidates](#managing-release-candidates)
  - [Reviewing 3rd-party Code](#reviewing-3rd-party-code)
  - [Transferring 3rd-party Code](#transferring-3rd-party-code)
- [6. Appendix A - Getting Started](#6-appendix-a---getting-started)
- [7. Appendix B - Updated Conventions](#7-appendix-b---updated-conventions)
  - [Throw errors for missing environment variables](#throw-errors-for-missing-environment-variables)
  - [List environment variables in `envVariables()`](#list-environment-variables-in-envvariables)
  - [Cakefile conversion](#cakefile-conversion)
  - [Add CHANGELOG.md](#add-changelogmd)
  - [Include `node` as a Travis build version](#include-node-as-a-travis-build-version)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# 1. LeadConduit Overview 

## What It Does 

LeadConduit is a real-time HTTP transaction handler, customized for use with online marketing leads. There are different use-cases, but the essential functionality is: the system receives HTTP POSTs of data, as from an online form submission. This post typically contains a consumer’s contact information, such as e-mail address, first and last name, phone number, etc. (It may also contain a lot of other data specific to the marketing campaign it’s part of. For example, mortgage-industry leads would contain details about the mortgage loan the consumer is shopping for: the size of the loan needed, their credit score, whether they qualify for a veteran’s loan offer, and much more.)

These lead posts are sent in to a LeadConduit **flow**, which a LeadConduit customer has set up to define the steps that should be taken with leads of that type. The flow includes what **sources** to accept leads from. Each source in a flow uses a particular **inbound integration**, which controls how the data on each post is parsed, and how the **fields** which make up the lead (“email”, “first_name”, etc.) are populated. How these integrations work will be discussed in much more detail later in this guide.

Sources are used for reporting, answering questions such as: “How many leads did Vendor X send in to this flow last month?” Each source may also have **acceptance criteria rules** defined for it, which allows the flow to immediately reject leads that don’t meet some bare minimum requirements. For example, if a particular vendor must always provide a valid postal code, this could be defined as a rule on that source.

Once a lead has been accepted in the flow, it proceeds to the remaining predefined **steps**. One type of step is called a **recipient** (in the UI, this type of step is presented as an “Enhancement” or “Delivery” step; from the standpoint of an integration developer, they’re essentially the same). This kind of step is where LeadConduit makes HTTP requests of other services, via a particular **outbound integration**. These integrations and how they work is the main subject of this guide, but at a high level they define what data is sent where, in what format, and how the response from that service is parsed. They also control how data will be added to the lead from that point on in the flow, which is referred to as **appended data**.

The other type of step that can be added to a flow are **filter** steps, which define criteria to stop processing and reject a lead. These are similar to the acceptance criteria mentioned previously, but they apply to leads from _all_ sources, and they can be placed after recipient steps. That means that their rules can also use appended data. For example, after a recipient step that sends the lead’s email address to an email-verification service, there would probably be a filter step immediately following it, with a rule such as, “if the email-verification service responded that this email is fraudulent, then stop processing now”.

After all the defined steps have been executed, or if a filter evaluation results in early termination of the flow, a response is returned to the original source of the lead. The format of that response is determined by the inbound integration, but generally includes LeadConduit’s unique lead ID and some indication of overall success (i.e., a good, accepted lead) or failure (a bad, rejected lead). The duration of this process for each lead varies, depending on the number of steps and the responsiveness of external services, but is typically only a second or two.

## How It Does It

The LeadConduit service provides two interfaces, referred to as the **API** and the **handler**. The API is used by the web client UI (as well as directly from other systems, in some cases), while the handler interface receives incoming lead posts and, of course, handles them. 

These two interfaces are provided by a single Node.js server application, written in CoffeeScript, and backed by a MongoDB database. The many modules that make up the server are published on npm.org. Some are public, while others are available only to internal ActiveProspect developers. Source code is published on github.com and is also a mix of repos that are public (i.e., open source), and others that are accessible only to members of the ActiveProspect organization.

Similarly, all inbound and outbound integrations are Node.js modules, written in CoffeeScript and published on npm.org. Some parts of each integration module are used by the API, while others are used by the handler. For example,  when a flow step is being configured, the list of fields required by an outbound integration will be shown in the LeadConduit UI (via data from the API). The majority of the integration code – how to formulate the outbound request, how to parse the response, and more – will be used by the handler at lead-handling time.
# 2. Key Concepts 

## Fields - Standard and Custom

Every lead can be thought of as a collection of fields. LeadConduit has a large – and growing – number of “standard” fields. These are predefined fields, with a meaningful name and a particular type. The full list is available in the LeadConduit UI at 
[https://next.leadconduit.com/fields](https://next.leadconduit.com/fields), but examples include: 

* `email` - a field for email address, of `email` type
* `postal_code` - a field for postal code (aka ZIP), of `postal_code` type
* `dob` - a field for date-of-birth, of `date` type
* `age` - a field for a person’s age, of `range` type
* `company.name` - a field for the name of a _company_ (not a person), of `string` type
* `mortgage.loan.insurance_fee` - a field for “the application fee required by a private mortgage insurance company”, of `number` type

There are also custom fields, which any customer may create, name, and use however they wish within their account. But we will be developing reusable integrations that can be used in any account, so we will only ever use standard fields. When necessary standard fields don’t exist, they will need to be created by a LeadConduit super-administrator (this would only be necessary when working on inbound integrations).

## Field Types 

All fields have a **type**. The default type is often `string`, but other types exist that provide a richer set of components. These are sometimes called “rich types”.

For example, many of the rich types listed below have a boolean `valid` attribute, which represents whether the data format is valid or not. If a `phone`-type field were given the value “do not call me”, it would not be valid.

* boolean
* credential
* date
* email
* gender
* number
* phone
* postal_code
* range
* ssl
* time

Here’s a full example of JSON representing a valid `phone`-type field:

```
{
  "prefix": "1",
  "raw": "5125551212",
  "area": "512",
  "exchange": "555",
  "line": "1212",
  "number": "5551212",
  "extension": null,
  "country_code": "US",
  "is_tollfree": false,
  "type": null,
  "valid": true
}
```

And here is an example of an _invalid_ `phone`-type field: 

```
{
  "raw": "do not call me",
  "valid": false
}
```

See also: full field documentation in the [LeadConduit reference](http://docs.activeprospect.com/leadconduit/reference.html).


## Inbound vs. Outbound Integrations 

As described so far, LeadConduit has many standardized internal fields to represent attributes on leads. Let’s consider the field for storing a lead’s first name (e.g., "Juan" or "Esther") as an example. In LeadConduit, that data belongs in the standard field  `first_name`. But a lead vendor posting the lead _to_ LeadConduit may use a different name to collect first-name on their webform, say, `fname`. Meanwhile, the [CRM](https://en.wikipedia.org/wiki/Customer_relationship_management) system receiving the lead _from_ LeadConduit may call the first-name field something else still, perhaps `name_1`.

The format of lead data may be inconsistent, as well. Our same hypothetical lead vendor may collect phone numbers on their webform with parentheses around the area code and dashes separating the line and exchange: `(512) 555-1212`. But it could be that the buyer's CRM system expects that data to be exactly 10 numeric digits: `5125551212`.

A lot of the value that LeadConduit provides is in solving these kinds of incompatibilities for our customers. And a lot of the work that makes that happen is in integrations. 

As mentioned previously, there are two types of integrations: **inbound**, to process data posted into LeadConduit, and **outbound**, which processes how data is sent out of LeadConduit. 

An inbound integration has three main jobs: it receives an incoming **request**, it parses that request and creates a **lead** with the parsed data, and it formulates the **response** that is given back to the submitter. 

An outbound integration also has three main jobs: it **validates** that the minimum required data it needs is available, it formulates the outgoing **request**, and it parses the **response** it receives, appending data to the lead as appropriate.

## Vars, Appended Data, and “The Snowball”

As a lead progresses through a flow, it accumulates data from each step. We sometimes call this "the snowball", because it's like a snowball rolling down a snowy hill, growing larger and larger as more snow sticks to it. In the code, this 'snowball' is contained in a variable conventionally named `vars`.  

We’ll see a lot more of `vars`, but in this JavaScript object, the originally submitted data is always stored under the key `lead`: `vars.lead.email`, `vars.lead.first_name`, etc. There is also some metadata that is available: `vars.submission.timestamp`, `vars.flow.id`, etc. And as each recipient step is run, that step’s integration adds more data, namespaced under its own key. For example, the TrustedForm integration adds data-points such as `vars.trustedform.outcome` and `vars.trustedform.user_agent`.

## Mapping Data

A key part of an integration’s interface is what data it provides (for an inbound integration) or accepts (for an outbound integration). We try to define the interface for integrations to reduce manual setup by LeadConduit users, but some setup is nearly always needed. Full control of what data comes out of (or goes into) an integration is accomplished by the ability to “map” that data.

### Source Mapping

On the inbound side, mapping typically only applies with the LeadConduit Standard inbound integration, which provides access to all the parameters in the lead’s HTTP POST body. Given those, it’s possible to “map” them to the LeadConduit standard fields. From our example earlier, where a webform is capturing first-name as `fname`, the user could configure the source to map that value to be stored in `first_name`. 

Custom-built inbound integrations, which will be discussed more later, usually do all of that “mapping” within the integration code. For example, incoming leads from Bills.com have a field called `phone_day`, which [the integration](https://github.com/activeprospect/leadconduit-integration-billsdotcom) uses to populate the LeadConduit standard field `lead.phone_1`. So, customers that use that integration don't have to worry about setting up a mapping for that.

### Recipient Mapping

On the outbound side, values can also be mapped for recipient steps. As will be discussed in more detail later, an outbound integration defines what data parameters it accepts, along with metadata hints about those parameters.

Take the TrustedForm Claim integration, for example. It has just one absolutely required parameter: `lead.trustedform_cert_url` (which shows as the more readable “TrustedForm Cert URL” in the UI). Because it is a value that normally exists on the lead from the start – as indicated by the `lead.` prefix – customers setting up the TrustedForm integration don't have to “map” anything. As long as the leads they send through that flow have the `trustedform_cert_url` field, the integration will just work.

That integration also defines other, non-required parameters, like `trustedform.scan_required_text`. If the user opts to use that feature of TrustedForm, they would map a value – probably a hardcoded string, perhaps some disclaimer text they require their vendors to use – in the UI. Once configured, that integration would then receive two values for each lead: the `lead.trustedform_cert_url` value (as before, because it’s on the lead), as well as the `trustedform.scan_required_text` value that had been configured in that flow’s mappings.

Some integrations have parameters that _must_ be configured before they can be used. SuppressionList Query Item, for example, can’t be used without knowing `list_names` (one or more hardcoded values, which would never be on the lead) and `values` (often `lead.email` or `lead.phone_1`, but could be any lead field).

## Step Outcomes 

Each recipient step can result in one of four possible outcomes: “success”, “failure”, “error”, and “skip”. Flow continues to the next step in every case, as only _filter_ steps can halt the lead’s progress through the flow. That said, it’s common to configure a filter step immediately following each recipient step, which could halt processing, for example, if the recipient step’s outcome was something other than “success”.

The outcome of the recipient is explicitly set in the integration, as will be detailed later, by setting the value of an append variable called, of course, `outcome`. The exact cases when these are set may vary from one integration to another, but these are the conceptual meanings.

### Success

Success indicates, at a minimum, that the transaction with the recipient service completed normally and returned a recognized response. This may mean that the record was successfully added to the service’s database, or that data was found for the lead data provided.

### Failure 

Failure indicates that a problem exists, one that would probably still exist if the same transaction were tried again. 

Examples: 

- the data provided already exists in the system’s database (i.e., it’s a duplicate)
- the data provided was rejected by the other system for some reason (e.g., the `postal_code` is one that the recipient isn’t buying leads for)
- no data could be found for the data provided (e.g., a lookup based on `email` found no data)

### Error 

Errors indicate that a processing problem of some kind has occurred. These can sometimes be corrected in a way such that if the same transaction were retried, no error would occur. 

Examples: 

- the recipient service is temporarily not responding (e.g., once the service is back up, the error would not repeat)
- some non-lead-specific data is wrong or missing (e.g., if the service’s API key is wrong, fixing it would stop the error)
- something about the integration’s request is wrong (i.e., a bug (gasp!) in the integration is causing the error)

### Skip

In the case where an outbound integration doesn’t have all the data it requires, it will cause that step to be “skipped”. This behavior is implemented by a function called `validate()`, described in full detail in the Integration API chapter. In this case, no request is even attempted to the recipient, since it could not possibly result in success.

Note that skip outcomes can also occur if the step has "step criteria" configured via the flow UI. For example, a customer could specify that an expensive data-verification service should not be used for leads provided from their own website (with a rule such as, "send to this recipient only if 'Source' is not equal to 'My Website'"). In a situation like that, the handler never invokes the integration in any way.
# 3. The Integration API

## Module Introduction

A LeadConduit integration is implemented as a Node.js module that conforms to a defined interface for what functionality it exports.

The git repository name should use the prefix `leadconduit-integration-`, followed by a descriptive name for the integration. For example, `leadconduit-integration-trustedform`. 

If you’re working on a proprietary or open-source ActiveProspect integration, that repo will be in the [`activeprospect` Github organization](https://github.com/activeprospect/). (If you’re working on a 3rd-party integration, it can be hosted elsewhere, so long as ActiveProspect reviewers have access to it.)

The module’s `package.json` includes typical boilerplate information, which doesn’t vary much from integration to integration: `name`, `description`, etc. Brand new integrations should start with a `version` number of “0.0.0”, and pull requests should not increment this number; it is incremented during the deploy process.

## `index.js` & Naming

A given integration _module_ may have more than one actual integration in it. It’s rare, but there are even some that contain both inbound and outbound integrations. More typically, an external data provider may provide more than one service or action endpoint. The SuppressionList module, for example, has three integrations: one to query items, one to add items, and one to delete items. These are all listed in the module’s `index.js`: 

```
module.exports = {
  outbound: {
    query_item: require('./lib/query_item'),
    add_item: require('./lib/add_item'),
    delete_item: require('./lib/delete_item')
  }
};
```

The `index.js` file may also optionally export a `name` attribute for the module. In most cases this is unnecessary, as the name is automatically derived from the package name itself.

Similarly, each integration within the module may optionally export a `name` value for that integration's endpoint. If not present, the name is inferred from that integration’s name. For example, the SuppressionList `query_item` integration, with no explicit `name` set, will be show up as “Query Item” in the UI.


## “request and response” vs. “handle”

There are two possible ways to build an outbound integration. One is referred to as "request and response style", the other is "handle style". 

When the service being integrated with is accessed by a single, fairly simple HTTP request, the first, "request and response", is preferred. With this approach, one function (`request()`) is used to create an object that defines how the transaction should be made, and another (`response()`) is given the result of the transaction to parse (see more details below). Meanwhile, the actual HTTP transaction itself is performed by the core LeadConduit application, not the integration module.

Other times, the service being integrated with may be more complex, requiring multiple requests to accomplish a single lead transaction. Or, there may be a 3rd-party library that can be used to perform the transaction. In cases like this the second approach is the way to go: a single `handle()` function is written to formulate the request, execute the HTTP request, and parse the response.

The remainder of this section describes both styles, and how they're defined.

## `request()`

This function takes a single parameter, `vars` (see below), and can access attributes of it as described in the `request.variables()` array (see below). It returns a JavaScript object that details how LeadConduit should make the HTTP call. That includes setting these attributes, as necessary: 

- `url` -- this is the full, valid URL of the service to send data to. This often includes data taken from the lead being processed. For example: `https://app.suppressionlist.com/exists/my_customers/hotlead@gmail.com`
- `method` -- the HTTP method to use: “POST”, “GET”, etc.
- `headers` -- an object with standard HTTP header attributes as key-value pairs. For example: `"Accept": "application/json"` 
- `body` -- for POST-type requests, the URL-encoded data being sent. This also frequently includes data from the lead. For example: `reference=123&vendor=Ace%20Leads%2C%20Inc.`

This JavaScript object is simply returned from `request()`, and then LeadConduit uses it to execute the HTTP transaction as described.

## `response()`

The complement to `request()`, this function takes three parameters: `vars` (see below), `req` (the request object), and `res` (the response object). It returns a JavaScript object that LeadConduit will “append” to the lead. This object includes a few standard attributes, but otherwise is defined by the the `response.variables()` array (see below). 

The standard attributes of the object returned by `response()` are `outcome`, `reason`, and `billable`.

### `outcome`

Outcome can be set to one of "success", "failure", or "error".

The difference between "failure" and "error" is usually between a transaction failing (failure) and a system failing (error). For example, if an integration intended to add a record in a CRM database got back a response indicating that a record is a duplicate, that would be a failure. For a lookup service, if the data being looked-up isn't found, that's typically considered a "failure" as well. "Error", on the other hand, is usually something like the remote system being unreachable, returning an HTTP 500, etc. 

One rule of thumb is that problems that would probably recur on a retry, such as a duplicate record, are “failures”, while those that might not, such as the service being unreachable, are “errors”. However, the details of when to use each outcome are usually specific to each integration.

There is a fourth possible outcome – "skip" – but that value is never explicitly set by an integration. It is only set by the handler process after evaluating flow rules, or when an integration's `validate()` returns a validation error message (see the section on `validate()`, below).

### `reason`

Reason must _always_ be set if the outcome is “failure” or “error”. This information will be seen in the LeadConduit UI, and may also be returned to the original provider of the lead, so the more human-understandable, the better. 

The UI also shows counts of these "reason" messages in reporting views, so making them unique per lead is a bad idea. For example, "user not found" can be shown as happening 200 times yesterday, but if the message is too specific – like "user John Smith not found", "user Jane Doe not found", etc. – then that aggregation isn't possible.

Usually, "error" is when something unexpected happens, so details such as the HTTP status could be included in the `reason`. Knowing that it was a 404 vs. a 500, for example, is helpful when troubleshooting. We also sometimes capture the entire server response; when it's truly an error, that response may not be valid according to that service’s API. For example, a 500 might just return an HTML error page.

### `billable` 

Billable should always be set for integrations that are resold through LeadConduit. That is, if ActiveProspect is paying the service provider, and in turn billing our customers for that service, this value is required. Other integrations that aren’t resold, such as delivery to a CRM, will omit the `billable` attribute.

The value assigned is the number of transactions that the LeadConduit customer will ultimately be billed for. This is usually “0” or “1”, and depends on ActiveProspect’s terms with the service provider. For example, if every Acme lookup should be charged for, regardless of whether a record is found and returned, then this would always be "1" (except for an “error” outcome). Alternatively, if only lookups that successfully return data were charged for, then this would only be "1" on success.

Note that the “0” and “1” here are numeric, not boolean. It’s possible that a single transaction may have a billable value greater than “1”. This occurs, for example, in the TowerData integration, which can be used to request up to sixteen data-points in one transaction. Each data-point successfully returned is added to the `billable` value.

## `request.variables()`

This function returns an array of objects that define the variables that can be used by `request()`. In other words, it describes the input to the integration. This information is also used in the LeadConduit UI, to allow users to set or override these values with mappings.

Each item in the array is a JavaScript object with these attributes:

- `name` -- the name that the variable will be referenced by. For example, `lead.postal_code`, or `list_names`
- `type` -- the type of the variable, such as `string`, `phone`, etc. 
- `required` -- a boolean value indicating whether this variable is required
- `description` -- descriptive text explaining what the variable means, or is used for. Can also include details about default values, as appropriate.

Example: 

```
{ 
   name: 'lead.trustedform_cert_url', 
   type: 'string', 
   required: true, 
   description: 'TrustedForm Certificate URL' 
}
```

The `name`, `required`, and `description` attributes are used to show the user what data can be configured for this integration (`type` is not; with some complex mappings, it would be impossible for the UI to know whether the type were being correctly matched).

If the integration needs to use values from the original lead, those are listed with a name prepended with “`lead.`”. Listing them that way lets the UI ensure those fields are added to the flow when the integration is added.

For example, the BriteVerify integration lists `lead.email` as its only request variable, and when a user adds that service to a flow, the UI adds `email` to the flow (if it isn’t already there), and no additional mapping is needed.

Note that the `required` attribute is used _only_ by the UI. Enforcing that “required” values are present at lead-handling time is solely the job of the `validate()` function (see below). 

Though the `type` value does not affect the UI, it is used by the lead-handler, which creates an instance of the specified type for each variable before invoking `request()` (or `handle()`). 

However, a specific “rich” type (see Key Concepts section on "Field Types") should only be used when it’s really needed; use the `string` type wherever possible. This avoids subtle bugs and unexpected behavior caused by the lead-handler’s automatic typecasting. If the integration needs to check `.valid`, or access other object attributes (e.g., `.area` or `.exchange`), then list it as `type: 'phone'`. Otherwise the integration will ask for a string, and LeadConduit will provide it that way. When a rich type is specified, care must be taken to “stringify” the value as necessary with the `.valueOf()` function.

Using rich types also requires extra care in test code; see details about testing in the Author’s Guide section.

In a “handle style” integration, this function is called `requestVariables()` (since there is no `request` definition to add `.variables()` to), but is otherwise exactly the same.


## `response.variables()`

Similar to `requestVariables()`, this function returns an array of objects that define the variables that can be appended to the lead by the integration. This information is used in the LeadConduit UI, allowing the user to create filters and subsequent mappings with this data. 

There are a few standard variables that are always included: `outcome`, `reason`, and `billable`. See the section about `response()`, above, for more about those.

What fields to include differs from one integration to another. For a CRM delivery, there may be little useful information to append, other than perhaps an ID returned for the new record created there. For lookup services, it may be best to list and append everything returned, or it may make sense to exclude some data, if it’s decided to not be of interest to LeadConduit users. Ideally these decisions are provided in a new integration’s requirements, but arriving at the final list is often an iterative process.

To ensure there aren’t appended-data name conflicts, the integration name should prefix each field name. The three SuppressionList integrations provide a good example: the `query_item` integration lists the variable `query_item.outcome`, not just `outcome`. That ensures that the value is unique relative to the outcomes of the other SuppressionList integrations (`add_item` and `delete_item`). If each one only listed `outcome`, then a filter step in a flow after both a `query_item` and an `add_item` step would only list a single value, named “SuppressionList Outcome”. There would be no way to differentiate the query outcome from the add outcome at that point.

In a “handle style” integration, this function is called `responseVariables()` (since there is no `response` definition to add `.variables()` to), but is otherwise exactly the same.

## `handle()`

As discussed in the section above (“request and response” vs. “handle”), some integrations can’t be built using the “request and response” style just described. One example is when an integration needs to make multiple requests per lead, such as a login request, a data transmission request, and finally a logout request. The `soap` integration in the LeadConduit “Custom” module is one open-source example; the `send` integration in the Email Delivery module is a simpler one, but is visible only by ActiveProspect developers.

Another case for writing a `handle()` function is when there is an existing library that does some of the work for us. The Clearbit integration is an example: it leverages [a Node module provided by that company](https://www.npmjs.com/package/clearbit).

The `handle()` function takes two values: `vars` (see below), and the callback function to invoke when it’s complete. 

The callback function takes two values: an error object, and the JavaScript object to append to the lead (i.e., as defined by `responseVariables()`, with `outcome`, `reason`, etc.).

## `vars`

The main data structure for lead data is conventionally named `vars` in these functions (see also: the Key Concepts section “Vars, Appended Data, and “The Snowball””). 

Integrations never directly add to or change the attributes of the `vars` object (in fact they are given only a copy of `vars`, so if they did change it, those changes would be lost). Instead, the LeadConduit handler manages adding data to it (aka building up “the snowball”), using the objects returned by `response()` and `handle()`, as described in previous sections. 

That leaves the single thing `vars` is used for in integrations: using the data it contains. This nearly always comes from the `lead` attribute, which itself contains all the fields that define the lead being handled (`email`, `first_name`, etc.). In an integration, those are fully referenced as, for example, `vars.lead.email`, `vars.lead.first_name`, etc.

All the lead fields used by the integration should be listed in `request.variables()`, as described previously. This restriction isn’t enforced by the handler, but it's essential. In other words, though it would be possible to use `vars.lead.comments` even if that field weren't listed as a request variable, that would inevitably cause problems for users.

Similarly, it’s technically possible to use data appended by _other_ integrations, such as using `vars.suppressionlist.outcome` (appended data doesn’t get appended under `lead`), but that’s also a bad idea. Doing that would require the user to have set up – and use on every lead – the other integration previously in the flow that this integration is used in. The appropriate way for this to be written is to have a request variable that the end-user can map the correct data to, whether it’s from a previous step or not. In this way, the integration is self-contained and independent of any others.

There are some other metadata values available on `vars`. They’re rarely used by an integration, but here’s an example to illustrate them (with some simple `lead` data, including `email`, a "rich" type):

```
{
  "submission" : {
    "timestamp" : "2016-11-28T21:44:42.699Z"
  },
  "lead" : {
    "id" : "583ca54afd2847153ae89b1b",
    "email" : {
      "normal" : "gina@chavez.biz",
      "raw" : "gina@chavez.biz",
      "user" : "gina",
      "domain" : "chavez.biz",
      "host" : "chavez",
      "tld" : "biz",
      "valid" : true
    },
    "first_name" : "Gina",
    "last_name" : "Chavez"
  },
  "account" : {
    "id" : "53a310fa9d29c9c72100006c",
    "name" : "ActiveProspect, Inc.",
    "sso_id" : "4d9a4c421d011c553e000001"
  },
  "flow" : {
    "id" : "564b6135d3754dcf205eae6f",
    "name" : "Sales Leads"
  },
  "random" : 95,
  "source" : {
    "id" : "53ab1f319d29c9ddf2000045",
    "name" : "AP Site Contact Form"
  },
  "recipient" : {
    "id" : "535e9f8c94149d05b5000002",
    "name" : "TrustedForm"
  }
}
```

## `validate()`

This function is technically optional but defined in nearly all cases. It is invoked prior to the `request()` (or `handle()`) function; its purpose is to ensure that the minimum necessary data is present to bother calling `request()` (or `handle()`) at all. See also: “Step Outcomes, Skip” in Key Concepts.

For example: consider a phone-verification service. If there is no phone data provided, or if what’s provided is not a valid phone number, then there's no point in spending the cost or processing time required to call that service. 

The `validate()` function takes a single parameter, `vars` (see above), and returns either nothing (technically, `undefined`), if the required lead data is present, or a string “skip” message if not. That message will be set as the `reason` text for this integration’s step, so as discussed previously, it should not include lead-specific data (see the “response()” section, above).

This error text should also be consistent with similar errors in other integrations. For example, the standard validate message for a missing email, used in many integrations, is “email must not be blank”.

Note that the `required` attribute on request variables, by itself, does nothing to the behavior of the integration (see “request.variables()” above). However, that metadata should match what variables the `validate()` function checks for. There is no automatic enforcement for these to match; they must be kept in sync by the developer.

Another type of exit is possible from `validate()`, which should be used when required environment variables (see below) are missing: an `Error` object should be thrown. This is treated differently because it’s not an issue with the particular lead being handled, but is a misconfiguration of the LeadConduit handler. This thrown error will alert ActiveProspect personnel to the problem immediately, so that it can be fixed. Examples of this can be found in the TowerData and WhitePages integrations. (Note: throwing an error for missing environment variables is a relatively new convention; you may see older integrations that simply return a string message in this case (you should fix them!).)


## `envVariables`

Sometimes there is key integration data that is static, but should not be hardcoded in the integration itself, such as API keys for resold services. These values should be treated like passwords, and therefore aren’t appropriate to be kept in source code, even in a private Github repo. Instead, they're set in system [environment variables](https://en.wikipedia.org/wiki/Environment_variable) and accessed via `process.env`; an example can be seen in integrations such as BriteVerify, Clearbit, and ZipCodes.com.

When an integration requires a value from the process environment, another item should be exported by the integration: `envVariables`. This is an array of strings, containing the names of any environment variables the integration needs. This is used to ensure that the app isn’t deployed without required environment vars.

When an integration with new environment variables is first deployed (to staging, and separately, to production), these values will have to be configured in the server environment. A member of the LeadConduit development team with server access can set this up for you.

See the section on `validate()` for the best practices on validating that required environment variables are present. 
# 4. Development Guide

## Getting Started

Tools to help get started are still in development. For now, it's common when building a brand-new integration to find an existing integration that's similar to yours to use as a template. For example, the SuppressionList module includes several integrations, each for a straightforward REST API call.

## Development Environment 

LeadConduit integrations are Node.js modules, typically written in CoffeeScript. To work on them, your development environment will need to include: 

- [Node.js](https://nodejs.org/en/) - latest 6.x, but note that we use `npm` 2.x, not the newer version included with Node by default
- [CoffeeScript](http://coffeescript.org/) - latest 1.x

Internal ActiveProspect developers also need access to our private accounts at Github.com and npmjs.com; see the Administration Guide.

If you're working on a new integration and you prefer plain JavaScript, you don't have to use CoffeeScript.

## Style Guide 

As with any style guide, consider these conventions as rules of thumb. The consistency that comes from following these will aid in troubleshooting and maintenance across the growing number of integrations on the LeadConduit platform.

The following are not in priority order, but are numbered for reference.

1. general guidelines
  1. Keep code clear, readable, and concise
  2. Names of functions, variables, etc. are camelCased (e.g., `parseCreditRate()`)
  3. Names of lead and mapped parameters are snake_cased (e.g., `vars.credit_rate`)
  5. Use local variables to reduce repetition of long data-structure paths (e.g., `custLoan = vars.lead.customer.loan.information.data`)
  2. Prefer CoffeeScript-style interpolation (`"#{last_name}, #{first_name}"`) over JavaScript-style concatenation (`last_name + ", " + first_name`)
  3. Handle simple logic in the template (e.g., to ensure empty string: `"#{vars.lead.postal_code or ''}"`)
  6. In tests, use nested `describe()` statements to logically organize test cases

2. module review checklist
  1. a freshly cloned repo should be able to have `npm install`, `npm test`, and `npm lint` run successfully with no errors
  2. `package.json` should have correct `name`, `description`, etc.
  3. `package.json` should have no unnecessary packages as `dependencies` or `devDependencies`
  4. `Readme.md` should have correct Travis badge code
  5. `index.js` should list `export` integration names under the `outbound` (or `inbound`) namespace (or else the UI won’t correctly show the endpoint names in dropdowns)
  6. `CHANGELOG.md` should exist and be updated for this change. Reference Github issue numbers if appropriate, and use the planned version number, even though it will not match `package.json` until `cut-release` is run
  
  7. integration source should have:
    4. no unnecessary `require`s
    8. no API keys, etc. hardcoded anywhere source 
    9. no stray, unused “helper” functions
    10. no unnecessary `export`s 
    11. the correct `Accept` header on outbound requests integrations
    12. no custom request variables, only standard
    13. correct descriptions, types, and required flag on all request & response variables
  
  8. integration tests (see below) should:
    15. have a validation test for each required request and `env` variable
    16. have a validation test for when nothing is returned (i.e., no validation errors)
    17. use the `leadconduit-integration.parse()` utility to create typed request variables 
    18. use the `valueOf()` function to stringify rich-typed variables as needed

  9. brand-new integrations should:
    1. include a large, high-quality PNG for the logo (not in the repo, but provided in some way with the initial review)

## Test Coverage

Thorough test coverage is an important aspect of integration development. Testing the various edge-case conditions that are common in working with other systems, and being confident that future changes won't cause a regression in behavior, are part of what make integration modules superior to customers simply using the general-purpose configurable (aka "custom") integrations. PRs with failing or pending tests are never approved.

Refer to test code for existing modules, located in the `spec` subdirectory, to help remind yourself of the kinds of cases to account for.

Tests can be run locally by running `npm test` (or the alias `cake test`) at the command line. 

Our [continuous-integration (CI)](https://en.wikipedia.org/wiki/Continuous_integration) process uses [Travis](https://travis-ci.com/). Each git branch should be set up to be automatically built. Within an integration repo, this is controlled by the `.travis.yml` file (note that it begins with a dot, and so may be hidden in some filesystem views), as well as the `scripts.test` value defined in `package.json`.

When adding a brand-new integration, there is a one-time setup to do to configure Travis to run on each commit; see the Administration Guide.

## Linting

A newer part of our standards is running the CoffeeScript [linter](https://en.wikipedia.org/wiki/Lint_(software)) on your code. This helps enforce coding styles, described in more detail below. This hasn't yet been added to our CI process, but should be run by authors prior to submitting PRs.

If many changes are suggested by the linter, as may be the case with older integrations, those changes should ideally be kept in a commit that's separate from the "real" (e.g., bug-fix) changes.

To run the linter, simply type `cake lint` in the module's home directory.

## Documentation 

Markdown documentation that describes the functionality of the integration should be included in the `docs` subdirectory. See the Zip-Codes.com integration for an example of the template to be used. Also, see the [integration cakefile](https://github.com/activeprospect/leadconduit-cakefile/) readme for how PDFs can be generated and uploaded to Google Drive.

## Development Cycle

When working on a brand new module, internal ActiveProspect developers will create a repo in the ActiveProspect Github organization. If you're an external developer, you can use whatever git-based source control you like. In either case, start by creating a new repo with just one file on the `master` branch: a `Readme.md` with a single empty line. Then add your new code in another branch, so that the merge PR will show it all as new code. That way, it's easy to comment on and discuss during the PR review process.

0. Create a feature (non-`master`) branch for your changes. If you're not in the ActiveProspect Github organization, fork the repo first as necessary.
1. Make as many commits as you want while you do your work
2. Don't increment the module's version number; that will be done later (new integrations start at "0.0.0")
2. Push your branch to Github when you're ready to have it reviewed
3. Travis should be set up to run this module's tests (see "Test Coverage" above), and all tests should pass before you create a PR
4. Create the PR
    1. use a short but meaningful name
    2. add any further explanation needed (for bug-fixes, reference the issue number)
    3. assign the PR to a single more-senior developer for review. If you're not sure who is able to or has time to review it, ask.
5. Make changes as needed per PR feedback, iterating until the PR is approved
6. Squash your commits as needed, down to semantically useful chunks of work. That may be a single commit, or it may be multiple, per your judgment (see [this blog post](http://eli.thegreenplace.net/2014/02/19/squashing-github-pull-requests-into-a-single-commit) for more information)
7. Merge your PR
8. The next step is to cut a new release of the module, as covered in "Cutting a Release" in the Administration Guide chapter

## Tips, Idioms, & Links

Following are some common things to know, keep in mind, or have handy for further reference.

### Useful references

- LeadConduit API docs: [http://docs.activeprospect.com/](http://docs.activeprospect.com/)
- LeadConduit integration docs: [http://docs.leadconduit.com/](http://docs.leadconduit.com/)
- npm's semantic version calculator: [http://semver.npmjs.com/](http://semver.npmjs.com/)

### Guard against null with '`?.`'

Use CoffeeScript's existential operator to soak up nulls. As [the docs say](http://coffeescript.org/#existential-operator): "The accessor variant of the existential operator `?.` can be used to soak up null references in a chain of properties. Use it instead of the dot accessor `.` in cases where the base value may be null or undefined."

### Send the right types in tests

If you create a `vars` object in your tests, the values will be JSON strings, integers, etc., and not the "rich" LeadConduit types that the integration may get from the handler. Use the type-parsing utility found in the `leadconduit-integration` module to automatically create those rich types as needed, as defined by the integration's request variables array. 

The usage is usually a line like this at the top of your test file: 

```
parser = require('leadconduit-integration').test.types.parser(outbound.requestVariables())
```

That creates a parser function based on your `requestVariables()` (or `request.variables()`, as the case may be). That function takes your test JSON object and replaces any attributes with their rich-type versions: 

```
vars = parser
  lead:
    first_name: 'Alexander'
    last_name: 'Hamilton'
    postal_code: '00123'
```

That yields this object, with a rich `postal_code` value: 

```
{ lead: 
   { first_name: 'Alexander',
     last_name: 'Hamilton',
     postal_code: 
      { [String: '00123']
        raw: '00123',
        country_code: 'US',
        code: '00123',
        zip: '00123',
        four: null,
        valid: true } } }
```

### Look for `leadconduit-integration` functions

The `leadconduit-integration` module is where common functions, like the type-parser just above, should go. Look there for utility code. 

By the same token, if you've written or found functions that _should_ be common, add them there.


### Use CoffeeScript's `for…of` to iterate object properties

It's common in integrations to need to iterate over the attributes of an object, and CoffeeScript provides a handy tool for this: the [`for…of` comprehension](http://coffeescript.org/#loops).

### "Mask" sensitive data 

The full details of all transactions are visible in the LeadConduit UI, but we mask, or obscure, the data that should not be. This happens automatically for some field types, such as `ssn` (for Social Security Numbers) and `credential`. However, sometimes it's necessary for an integration to manually mask data. 

The key to understanding how this works is knowing that the integration's `request()` or `handle()` function is actually executed _twice_ by the handler process: once for real, and a second time in a kind of emulation mode to capture the details for the event record. So, to mask data from being captured in that second run, the integration simply writes over the necessary parts of `vars` _after_ the `request()` function has used them. 

For example, from the ZipCodes.com integration's common `createRequest()`: 

```
  vars.apiKey ?= process.env.ZIPCODES_COM_API_KEY

  req =
    method: 'GET'
    url: "#{url}#{body}key=#{vars.apiKey}"

  vars.apiKey = Array(vars.apiKey.length + 1).join('*')
```

The first time this is run, `vars.apiKey` is not set, so the `?=` CoffeeScript operator assigns it the value from the process environment. After that value is used to formulate the URL, it is replaced with a string of asterisks. 

The second time it's run, `vars.apiKey` will still be that string of asterisks, and so will not be assigned the real API key value. The URL assignment will include those asterisks, and that value will be captured in the permanent record of the event. (Using that wrong value won't cause it to fail, because that second transaction isn't really made.)

To test this, simply invoke `request()` twice, as in this example (also from ZipCodes.com):

```
before ->
  process.env.ZIPCODES_COM_API_KEY = '1234'

it 'should mask the API key', ->
  vars = {}
  req = common.createRequest('query?', 'http://api.zip-codes.com/', vars)
  assert.equal req.url, 'http://api.zip-codes.com/whatever/query?key=1234'

  req = common.createRequest('query?', 'http://api.zip-codes.com/', vars)
  assert.equal req.url, 'http://api.zip-codes.com/whatever/query?key=****'
```

# 5. Administration Guide

Some integration development and administration tasks can only be performed by ActiveProspect, Inc. personnel. These include cutting releases, adding new integrations to the platform, and deployments.

_Note: although this guide is currently published publicly, if you're outside the ActiveProspect organization, the information in this section isn't of use to you, and can be ignored._

## Logging in to npm

 When correctly logged in, you should get `activeprospect` as the response when you run `npm whoami`. You should also be able to successfully run, e.g., `npm install @activeprospect/leadconduit-briteverify`.

 To log in, run `npm adduser`, and answer the prompts:

 ```
 Username: activeprospect
 Password: _ask a teammate_
 Email: (this IS public) dev@activeprospect.com
 ```

## Setting up Travis CI for a new integration

When adding a brand-new integration, there is a one-time setup to do to configure Travis to run on each commit:

1. go to the [ActiveProspect profile](https://travis-ci.com/profile/activeprospect)
2. find the new github repo on the list (you may need to click the "sync account" button)
3. click the repository switch to turn it on

The next commit that's pushed to the repo should trigger a build.

## Running LeadConduit Locally

* before npm-publishing, you can hack it locally using `npm link`
* in the new integration directory (make sure `package.json` has the right name info), run `npm link`
* in `leadconduit-integrations`, run `npm link @activeprospect/leadconduit-whatever`
* in the local handler & API , npm link in `leadconduit-integrations`

_todo: add full details, incl. `leadconduit-deploy`_

## Version Numbers

Module version numbers follow [semver guidelines](http://semver.org/), with "major.minor.patch" form. Our guidelines are similar to general usage, but choosing what level to increment on a release can be subjective. Make your best call, or ask a teammate for a second opinion if you're not sure.

- the **major** version is incremented whenever a breaking or incompatible change is made. We do not typically follow the guideline that production-ready code is promoted to "1.x.x"; it's common to see stable modules with "0.x.x" (even "0.0.x") in use. 
- the **minor** version is incremented when new functionality is added that isn't incompatible or breaking. 
- the **patch** version is incremented when a bug is fixed or trivial improvement made. 

## Cutting a Release with `cut-release`

Creating a new integration release, major or minor, is done with the command-line tool `cut-release`. This ensures all changes are committed and branches are correct, prompts for how to update the version of the module (per [semver guidelines](http://semver.org/)), tags the git repo, and publishes the module to npm. See the [readme](https://github.com/activeprospect/cut-release) for more details on installing and using it. 

Note that as with any `npm publish`, _everything_ in your local module directory will be published. Be sure there aren't temporary files, test data, API keys, or anything else that shouldn't be included in the published module.

You'll need to be logged in to npm as `activeprospect` (see Development Guide) for this to work.

## Deploying a New or Updated Integration

Once a new or updated integration is published to npmjs.com, it's ready to be deployed. Integrations are made available in LeadConduit via the dependencies listed in the [`package.json` of the `leadconduit-integrations` module](https://github.com/activeprospect/leadconduit-integrations/blob/master/package.json). If your updated module satisfies the version specified there, then no changes are necessary before starting the deploy. 

However, if this is a new integration or it _doesn't_ satisfy the semver expression, then the dependencies must be updated. 

For a new integration, add it to the list, in alphabetical order, with the semver pattern `~0.0.1`. For an updated integration, modify the semver to match as appropriate.

In either case, the integrations module itself now needs to be updated and released, too. Make the above changes on a branch, create a PR, have it reviewed, etc., through to `cut-release` (new integrations are usually treated as an increment to the "minor" version of `leadconduit-integrations`).

### Deploying on Staging 

In nearly all cases, we deploy new and updated integrations to the "staging" LeadConduit instance first, so that you can verify the functionality, and so it can be acceptance-tested by others. Though production updates and releases are announced in the `#incidents` channel, that is not necessary for changes in staging.

This can be done by anyone on the development team, using the commands below in the `#leadconduit` channel in the ActiveProspect Slack. Prior to running this, look for a green dot next to the "staging1" bot in that channel. You may want to run `staging ping` to make sure it's responsive (it should respond, "pong!"). 

In the easier case, where `leadconduit-integrations` didn't have to be changed, you can tell the bot to just update that single integration by running this command (for a private package called "whatever"):

```
staging leadconduit update @activeprospect/leadconduit-whatever
```

Or, for a public package named "whatever", you can save some keystrokes:

```
staging leadconduit update whatever
```

After a moment, it should respond with a message that the integration was updated, listing the new version number as confirmation. Since staging isn't heavily used, and it's unlikely that changes to any particular integration will bother anyone, you can run an update there whenever you want.

However, for a new or significantly updated integration, which required `leadconduit-integrations` to be updated, the entire application has to be deployed. In this case, you should ask (in the `#leadconduit` Slack channel) if a full deploy to staging is okay for everyone. Usually it is, but if a release candidate of the app is being tested there, your deploy would replace it with "master".

Once you're ready, the command is simple:

```
staging leadconduit deploy
```

### Deploying on Production 

The process is similar for production deploys, but of course must be handled with greater care so that live lead-processing isn't affected. Therefore, though the commands are virtually the same (except specifying "production" instead of "staging"), not all developers have permission to issue the production deploy commands. When your integration is ready to go to production, ask a senior developer to deploy it.

As of this writing, there are two production servers, which can also be addressed separately by the deploy directives: `app3` and `app4`. 

### Rolling back a deploy 

The deploy commands can also be used to deploy older versions, i.e., to roll back a release that has a serious bug. This is done by adding the version number to the end of the command, like this:

```
staging leadconduit update @activeprospect/leadconduit-whatever --version=0.0.6
```

### Additional Setup for New Integrations 

#### Database Changes

For brand-new integration modules, there also needs to be a record inserted into the database for the new "entity". This is done by running something like this:

```
db.entities.insert({
  "name": "Whatever",
  "account_id": null,
  "logo_url": "https://s3.amazonaws.com/integration-logos/whatever.png",
  "source": null,
  "recipient": "other",
  "module_ids": ["leadconduit-whatever.outbound.delivery"]
});
```

For modules which have had a new integration added, the `module_ids` array will need to be updated. 

A senior developer or administrator can update these database records for you.

_todo: more details: staging vs production, automatic db sync, etc._

#### Environment Variables

If a module requires a new or updated environment variable (i.e., has exported the `envVariables` array), those are provided by the application config files `/etc/init/leadconduit-api.conf` and `/etc/init/leadconduit-handler.conf`. A senior developer or administrator can get those files updated for you. 

#### SSO Billing Information 

For integrations that will be resold by ActiveProspect – that is, integrations that set the `billable` attribute – the pricing details for that service must be configured in SSO before the integration is in use by customers. See [this SSO config file](https://github.com/activeprospect/sso/blob/master/config/products.yml), and contact an SSO developer for help.

#### User Interface Changes 

New integrations, especially those that are resold by ActiveProspect, may also need to have description and pricing information added to the LeadConduit UI. See [this client source file](https://github.com/activeprospect/leadconduit-client/blob/master/public/app/views/flows/edit/create/resoldServices.js), and contact a LeadConduit UI developer for help.

## Managing Release Candidates 

Working with release candidate code – i.e., a new version that shouldn't be included in a production deploy yet – is kind of a pain in the neck, so we don't usually bother if we don't have to. If you do have to, here's roughly how to do it:

* in the integration being updated:
    * update integration version to a level that _won’t_ be picked up by what’s specified in `leadconduit-integrations`’s current production `package.json`
    * publish it as usual
    * since the version is higher than `leadconduit-integrations` is looking for, regular deploys won’t pick up this new update
    * _example: `leadconduit-integrations` listed “leadconduit-whatever”: “^1.0.0”. That would get any 1.x.x, so the integration has to update to “2.0.0” to not match_
* in `leadconduit-integrations`:
    * ensure the integration dependency version for the "whatever" integration will include that new version (e.g., "^2.0.0")
    * increment the version of this module (`leadconduit-integrations` itself) so that it won’t be picked up by what’s in production for `leadconduit-api`; publish as usual
    * _example: to now pick up the new 2.0.0 version of the `leadconduit-whatever` integration, that dependency could be listed as “^2.0.0” here. The `leadconduit-integrations` module itself was “1.1.3”, suppose `leadconduit-api` specifies “~1.1.0”; then this has to update to “1.2.0”._
*  in `leadconduit-api`:
    * ensure the version of the `leadconduit-integrations` dependency listed here will include new version set above
    *  increment the version of this module (`leadconduit-api` itself), with an “-rc.1” suffix
    *  commit & push, wait for Travis, cut-release as usual
    *  _example: in the `leadconduit-api` package, the `leadconduit-integrations` dependency, previously “~1.1.0”, gets bumped to “~1.2.0” If this package’s own version were “1.8.3”, it would now become, say, “1.8.4-rc.1”._
* deploy to staging, specifying that “-rc.1” version
    * if anyone does a production deploy in the meantime, the “-rc.x” versions won’t be picked up as “latest”, because semver omits those versions from consideration.
    * _example: `staging leadconduit deploy --version=1.8.4-rc.1`_
* iterate & test as needed, incrementing the integration's version number along the way
    * due to how the semver is set up, you probably won't need to cut a new release-candidate version of the parent API module during. Subsequent re-installations of "rc.1" will pick up the latest modules that match the semver.
    * _example: a bug is found in the "whatever" integration, it it's fixed and republished as “2.0.1”. It can now be re-deployed with the whole app (with `--version=1.8.4-rc.1`) or with the simpler `staging leadconduit update` format (see above for details on deploying just an integration update)_
* after everything looks good and it's ready publish for real:
    * remove the “-rc.1” from the `api` module and deploy as normal 


##  Reviewing 3rd-party Code 

In addition to the usual style and logic guidelines (see Development Guide), some of the things to watch for when reviewing code not written in-house, or by developers who are unfamiliar integrations development:

* check for any kind of infinite loop or unending recursive calls
* ensure there are no synchronous node calls (e.g., `fs.readSync()`)
* ensure no sensitive data (API keys, etc.) is hardcoded anywhere in code
* make sure `billable` is set when needed
* ensure any sensitive data is "masked" as appropriate
* examine dependencies used, watching out for new or unusual ones


## Transferring 3rd-party Code

If an external or third-party developer has created a module which they're willing to transfer to ActiveProspect for ongoing ownership and maintenance, here's an abbreviated list of steps:

1. invite an owner of the original repo to the [temp_admin team](https://github.com/orgs/activeprospect/teams/temp_admin)
2. owner goes into repo settings, clicks “transfer this repo” button, confirms with repo and our org name
3. remove that user from the `temp_admin` team

# 6. Appendix A - Getting Started 

_Coming soon_

For now, the best way to get started is to use an existing integration module as a reference (or even duplicate it, and use it as a template). For example, [leadconduit-trustedform](https://github.com/activeprospect/leadconduit-integration-trustedform).



# 7. Appendix B - Updated Conventions

Over time, we realize or discover new, better ways to do things in integration modules. But because there are so many modules, it's not usually worthwhile to revisit all of them at once to make those changes. Instead, we try to make these changes when we're fixing a bug or adding a feature to a module. The list below are updates that should be made whenever feasible.

## Throw errors for missing environment variables

If a required environment variable is missing, that's a problem that can never be fixed by the user, it can only be fixed by an ActiveProspect developer. That's why the check for such environment variables in the `validate()` function should throw an error, not just return an error message that causes a "skip" outcome.

An example, from the White Pages integration:

```
validate = (vars) ->
  throw new Error 'Missing credentials, contact ActiveProspect support' unless process.env.WHITEPAGES_LEAD_VERIFY_KEY
```

## List environment variables in `envVariables()`

When an integration needs environment variables, they should be declared in an array exported by the integration, as in this example from the ZipCodes.com integration:

```
module.exports =
  envVariables: ['ZIPCODES_COM_API_KEY']
  ...
```

## Cakefile conversion 

Originally each module had its own copy of a full `Cakefile`, approximately 35 lines long. That has been replaced with a separate module: [`leadconduit-cakefile`](https://github.com/activeprospect/leadconduit-cakefile). The `Cakefile` still exists, but should have a single line: 

```
require('leadconduit-cakefile')(task)
```

To make this update (the BatchRobot integration can be referenced as an example): 

1. add an entry for the current version of `leadconduit-cakefile` to the `devDependencies` section of `package.json`. this can be done by running: `npm install -D leadconduit-cakefile`.
2. remove the entry for `mocha` from `devDependencies` (it is included in the `cakefile` module) and delete that module (e.g., `rm -fr node_modules/mocha/`) 
3. replace the contents of `Cakefile` with the line above
4. run `cake test` or `cake build` to verify everything's set up correctly 


## Add CHANGELOG.md

Originally changes were not tracked in a changelog, but now they should be. If there is no `CHANGELOG.md` file in the root directory, add one with content like this: 

```
# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [0.0.7] - 2016-08-05
### Fixed
- Add this changelog

## [0.0.1] - 2015-06-16
### Added
- Initial version
```

Finding the date of the first published version is interesting, but note that it's not necessary to dig up the history of all past versions. 


## Include `node` as a Travis build version

Originally the versions of Node.js specified in each module's `.travis.yml` included the current known major versions (`4`, `5`, etc.). Travis also provides a way to automatically include the latest version, with the keyword `node`. 

In other words, a module's `.travis.yml` should look like this (the numbers may vary over time, but `node` should always be included): 

```
language: node_js
node_js:
  - 6
  - node
sudo: false
```
