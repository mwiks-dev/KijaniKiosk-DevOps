| Directory   | Owner       | Group       | Mode                   | Reason                                                                             |
| ----------- | ----------- | ----------- | ---------------------- | ---------------------------------------------------------------------------------- |
| api         | kk-api      | kk-api      | 750                    | Only API service requires full access                                              |
| payments    | kk-payments | kk-payments | 750                    | Isolates payment service                                                           |
| logs        | kk-logs     | kk-logs     | 750                    | Only logging service manages logs                                                  |
| config      | root        | kijanikiosk | 750 (dir), 640 (files) | Root owns secrets while authorized services can read them                          |
| shared/logs | kk-logs     | kk-logs     | 2770                   | SGID ensures new files inherit the logging group; ACLs provide fine-grained access |
