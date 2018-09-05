# Testing Plan

## Introduction

As of this writing (July 2018) this app has four tests, two of which pass.

Obviously, this app was not written with testing in mind.

## Goals For Testing

### Support Upgrading

The app is running in production with Perl 5.14 and Mojolicious 2.46
(yes, from 6.5 years ago. Yikes.)

Obviously, we want to get those both upgraded. Having test coverage
will make it easier to handle any issues brought on by the upgrade.

### Ensure Correctness

I have the normal needs to add features and fix bugs.

Additionally, I may at some point port the backend to javascript or
python.  While this would argue for not testing the backend using
Mojo-specific test methods, my currently plan is to do so for
simplicity and speed. Porting tests later, if needed, should be pretty
simple.

## Steps To Testing

### Testability

Currently the app has no real support for testing.

The issues I can already identify are:


1. Test DB

   Currently the DB location is just hard coded in the code. I expect
   that this will need to be changeable by tests.

2. Google Login

   Almost every piece of functionality is behind Google login. Simply
   getting the tests to skip authorization isn't enough, because the
   identification of Google login drives all the individual access
   decisions.

3. JavaScript / Websockets / Browser Issues

   The app uses a bit of javascript, but it's currently not a fully
   client-rendered app or anything like that.

   The chat system does involve both some javascript and some
   websocket use, including sharing a socket across tabs (if I
   remember correctly.)

   I may need a browser-side test suite, possibly even with multiple
   browsers, as I've run into some cross browser issues.

### Writing / Coverage

I don't plan on measuring coverage, but a number of areas concern me
based on the above goals and past issues.

1. Async / Event Loops

   Some of this code got pretty hairy, and I expect 6.5 years of Mojo
   improvements could have affected this support quite a bit.

   Also, porting to another backend may require significant rethinking
   of this code, so testing the functionality will be important to
   prevent issues.

2. Websocket

   This is a potential issue from both the Mojo and browser sides.

3. Google Integration

   Not to run all the time, but having tests that cover google docs
   functionality would be useful, as I'm never certain when Google has
   broken something. Having a manual test suite to confirm
   functionality would help.

