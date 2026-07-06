# nologin vs false

I chose `/usr/sbin/nologin` for all service accounts.

Reasons:

- It prevents interactive logins.
- It prints an informative message explaining that the account is unavailable.
- It still allows the account to own files and run services.
- It is the standard practice for Linux service accounts.

`/bin/false` also prevents logins by immediately exiting, but it provides no explanation to the user.

Locked passwords only prevent password authentication. They do not prevent login methods that bypass password authentication (such as SSH keys), so locking alone is not sufficient.

Therefore `/usr/sbin/nologin` provides the safest and clearest mechanism for service accounts.