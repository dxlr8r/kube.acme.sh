{
  // because we are using `+:` the content of labels will be added to the default labels, instead of replacing them
  labels+: {
    example: 'true'
  },
  // all fields in acme_sh are required
  acme_sh: {
    email: 'me@example.com',
    args: '--issue --dns dns_provider -d hello.example.com',
    env: {
      DNSProvider_Token: 'mytoken',
      DNSProvider_Secret: 'mysecret'
    }
  },
  // create the secret with the certificate in these namespaces
  target_namespace: ['testing', 'default']
}
