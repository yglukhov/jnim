jbridge - API design principles
======================================

1. Use exceptions, do not use ``Either`` like types in the API. Because Java will throw an exceptions
   and we will mix FP style error handling with exception handling.
2. Use modules. Don't put all eggs in one basket. Write independent tests for these modules.
