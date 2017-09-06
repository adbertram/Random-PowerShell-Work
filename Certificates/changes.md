### Updates to Certificates scripts/functions:

Sep 2017, by Matt Boren (@mtboren)
- in `New-CertificateSigningRequest` function:
    - increased functionality: added ability to specify Subject Alternative Name attribtutes for CSR via new `-SubjectAlternateNameDNS` parameter
    - added `-WhatIf` support, which returns the proposed contents to use for .inf file with `certreq.exe` invocation
    - increased convenience factor: added feature that uses the local computer name if `-SubjectHost` parameter not specified
    - completed usefulness of certs for browsers that no longer use the Subject property of a cert, but instead rely on SAN values only -- CSRs now automatically include the SubjectHost value in the SAN field
    - increased flexibility: removed unnecessary requirement on consumer to use ".req" file extension for resulting CSR file name; while it might be standard, it should not be mandatory
    - added helpful tip in `.Notes` section on how to inspect new CSR file with `openssl.exe`, so one knows how validate the contents of the CSR before submitting it for a certificate
    - bugfix: fixed `Signature` value in `[Version]` section of INF contents: `$Windows` was being interpreted as an empty variable, instead of as a literal (needed to escape the `$` character)
