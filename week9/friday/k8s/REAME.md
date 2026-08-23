# KijaniKiosk Kubernetes Deployment

All resources in this directory target the `kijani-project` namespace.

## Secret

The `kk-payments-secrets` Secret is intentionally not committed.

Expected Secret:

kk-payments-secrets

Required keys:

- DB_PASSWORD
- STRIPE_API_KEY
- JWT_SECRET

Values must be obtained securely from the team.

Example recreation command:

kubectl create secret generic kk-payments-secrets \
  --from-literal=DB_PASSWORD='<team-value>' \
  --from-literal=STRIPE_API_KEY='<team-value>' \
  --from-literal=JWT_SECRET='<team-value>' \
  -n kijani-project

Do not commit actual Secret values.