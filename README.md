# Securing Kafka resources with Authorino

This is a proof of concept on securing Kafka resources – most notably Kafka topics – with [Authorino](https://github.com/kuadrant/authorino).

The implementation should work with Authorino v0.2.0-pre and relies on [Strimzi](https://strimzi.io) v0.23.0. It is quite limited regarding the types of permission that can be modeled. It is NOT meant for production.

**Characteristics of the implementation:**
- Relies on Strimzi support for Kafka broker OAuth authentication
- Relies on Strimzi support for Kafka broker authorization with Keycloak
- Does NOT use Keycloak
- Uses Authorino + Envoy + a bouncer HTTP service ("JWT decoder"), to issue OAuth access tokens and to provide the user permissions ("pretending to be" Keycloak Authorization Service API)
- Clients authentication is handled by Authorino and based on API keys, which are exchanged for short-lived OAuth access tokens (Authorino Wristband tokens)
- Connection with the Kafka brokers is established bearing the Authorino Wristband token, which are verified and validated by the broker after fetching the JWKS from an Auhtorino endpoint
- Permissions of the clients are stored in the annotations of Kubernetes `Secret`s that represent the API keys
- Kafka authorization request (based on Strimzi's `keycloak` authorization type) just bounces back permission claims already present in the Authorino Wristband token obtained and used in the authentication phase

**Limitations of the implementation:**
- Not very different from Kafka's standard ACL-based authorization, with the extra limitation that the API keys can only store permission info about one Kafka resource at a time.
- OAuth access tokens (Authorino Wristabnds) are only supplied on client startup, and neither the clients, nor the Kafka brokers, refresh the token afterwards. Consequently, permissions last until the token expires or the restarts and obtains a new one again by exchanging with the API key.
- Still based on the reverse-proxy approach with Envoy and the bouncer "JWT decoder" service, not leveraging the gRPC connection with Authorino as an authorization service directly integrated by the Kafka brokers.
- Cannot leverage proper authorization policies (e.g. OPA, Authorino JSON authz policies) that evaluate, per request, based upon combination of principal information (present in the access token) and resource/operation information, due to constraints of Strimzi's `keycloak` authorizer, which does not supply information about resources nor operations on the request for permission; rather, the authorizer only provides the access token and expects a full list of permissions in the response.

#### Setup and Access sharing flows

![UML - Setup and Access sharing](http://www.plantuml.com/plantuml/png/jLRHJjj047ptLwpodXZA2x8Q14ffLI9L252HghnSrajyihrdtQqJXQ-lVPo9uu8gclJHuzNCpipvaaidoafT5f7BDLVAgX9AmmOpQqe2iJL5aMWf2Eu9Qwjv1NFrb2jOMfEJTR3Hai5LBPbfNfeeKYZ6WjiwbPQQm-FeZfofBHAO3PCTHOsIQDILOe5RQz8QoUw1CyEkBWVWQ5uloJ89ERYw_RvFSyrhi-qZkwtsIMuU7o0bDEbm4MyiYgRJnglK5KodKUS3nXT_g4CIvbu2KOqQiMXKeWr7R8IWe2T9G5Nw9rdNe0cWuIUzcgXkjScPGrNGX4dYzUcIH9qkkAaYRSdjMYCjs5M4oO81CkCQEafNDCbRpObROulhj1MMhPUQqxR5DbOxMQgMA1EfN1B7hw9ZerFSKIJd9-TdiN-C1ow6dfiSTh520dU4Xb4N5EtGmSXCOKO-dH_1_STIzKpF_pbKh_DUg4Qd7W4WJYkZMGx9zC1oGXZ7xkRNFtI3HUs4x7kj10jYTVci9zg4AZvrLNYINX7xCHqQSJ-hG1QuzXXEJcBC2FEtqWms-qbwfF_gNfGLODfqQOIHGT1VIJ3RrGutZ_FxVcxVhXyEy1jFDbGKuvpDXcDJ4UjqZ8QPK68aAwv_0iBkB-fMhp99_3f3RztfyE_yfPWfIw0GoRdsRXnUwk-Sc9ab9GHLkELR67BQzjrtdoPQaWKhPYFUb_FdmZiUjuxZsf5bLL8Im8vqC6R3OWc8gJGcAPLcC68gia43Hc75B-JGwYN1ezL2e-DzO4FlRqPtsmqb8Uaml5VKPrNfLzVZzg6PkFXW5HX-MuzQHI0zj8hN3kv8fKUiOEZvpSXcOUZl5GIwNWNH9N7Q_f7w3G00)

#### Kafka producer flow

![UML - Kafka producer](http://www.plantuml.com/plantuml/png/fPBBRnen4CRl_Yj6N7eYfEebMaKebA8-E0I5AAWIKcMy0rYxVdGyIqJ_-dfvEEm2LTNUThoVvvlFyti8B8ahKufGQEibIGF6MQVMv0m2KuL2iEOIOK8khrGifM974BP1vaRRGzbvmk0gKWZkrI9rHEp5McalBH-lKkDmw6oeJEkmCwuMI1OP0mmcNvjjHdRZjesJGSLhHzgwPfDlisV8KRcyFSXOBWifn74UwFRtJI639_nPOM1u9Hru8Mqkh6C4qgirP_1vz0nhPf_rUfYlyAQe6zs4ZUgnAz3ExM6INvAriraz-tZq7Uwbrrr_SEjAtIrmsnTxo-YTneTizuqsJYePHVhHLht8KkTHKHj0RDPGfYpJoljosuvIuZ8cqI5akoWXPf77srsdS_MMAhkxlVlGsvLHamRJBYRrX4iamln75P2iD9Z1Jfc2pYs5_JaxhrMMet5p6vJp6Bs7X7M0JnWKwGN2Z3HZUfFMyXfL_9rGQknmjrR8QgGiAcviRfOUOQywaRyWwUMsjpcywILfSidWSNp9ywW0Wo785JQyEr-mB5r7bCvvU7yR1EolNU9EdW8KXIShcpnE4tsrx8G-jKPLdD7t4IKXmNq2e1yRNgMkleXHS0Mwz4w9lJUk0FwAltTH-By8fdZ_GXV05RwWMQV5nXzjY5AICuw6Cgu1F9A9oUA4GU0bt8RrhXgoCycK2QNv4qiNqHmCnq8yHDFAbBy1)

#### Kafka consumer flow

![UML - Kafka consumer](http://www.plantuml.com/plantuml/png/fPJFRjim3CRlUWeYbvtITDYbC8gYNHRiJmuDqgB5W0238ZEnO5lKA3b5zlIJ7LUpqWJOi9j9VIBvYJ_urdd9lgahuKfjh6HPGqs6LC5K8tXkK0YlVOKm9UEQEeHIUM9mUoVpMfi-72tHKSCAWLuCyaY4MbuhRQNni63A6uMS9FjwQN8qRzR81Zqwk5jyJSlCp8xsIUQkyGMnDfGM-VRy23agoey7cSjDAOLuRGtZcqDHo629Fnjq7bvOEx-M9XU6F0BhRU4p-3nxXC9xcqqcc6_necmBNRYTcdWgqQnCFyalwJMPh9rzFliErzBgiUgxZQKUbxY_4OUMeNSS7xBk6utNIdeKyU1OzIGhdGT5sm12iKGPlJmqrbRxOoiLRe8JxLpMMN71YtozFIQTgp-kiglBgm-JBWoQE9YcuDGoRf0Pyn-DGpQonWmwPJIwCkmEUKzMgop7cbR6AR8OUdz2frYl4POey_WMHqjBed0SQKbsrwqJilRGeFB9nfwZ-Kurb3yXwyr-iklVyfGqTidWVdwkPvk36fsJMnGLaONtbqv0Bpd1bXn24eI3jIpk7o9XhMn0c2fGbMy8-uYIaU4wBlac53nBLdiHW-0yMEcR3DW1-2l6tWNX_s8MxVqBGG1d688qZiiB1yUWH0TlM9bALI1Ov3euqcISm5D8JTiT9R8JACNF2CtWmKPViAfe96v3_VP__1i0)

## Instructions

Steps 1-5 below are for installing and deploying Authorino on a Kubernetes cluster started locally with Kind, using some Authorino trial tooling from the Authorino repo. If you prefer handling Authorino installation and deployment by yourself, perhaps on another Kubernetes server of preference where you want to try this PoC, you can skip directly to step 6. In this case, make sure to create on your Kubernetes server a `Namespace` named `kafka`, where Authorino and all the other resources involved in the PoC must be created.

1. Clone Authorino repo

  ```sh
  git clone git@github.com:kuadrant/authorino.git && cd authorino
  ```

2. Start a local Kubernetes cluster with Kind

  ```sh
  make local-cluster-up
  ```

3. Install cert-manager and Authorino CRD

  ```sh
  make cert-manager
  make install
  ```

4. Create the namespace for the project

  ```sh
  kubectl create namespace kafka
  ```

5. Deploy Authorino

  ```sh
  AUTHORINO_IMAGE=quay.io/3scale/authorino:latest AUTHORINO_NAMESPACE=kafka make deploy
  ```

6. Clone this repo

  ```sh
  git clone git@github.com:guicassolato/strimzi-authorino.git && cd strimzi-authorino
  ```

7. Install JWT decoder and Envoy proxy

  ```sh
  kubectl -n kafka apply -f jwt-decoder.yaml
  kubectl -n kafka apply -f envoy-proxy.yaml
  ```

8. Install the Strimzi operator

  ```sh
  kubectl -n kafka apply -f strimzi-install.yaml
  ```

9. Create the `Service`s and Authorino service protection layers to handle Kafka client authentication and authorization

  ```sh
  kubectl -n kafka apply -f authentication-service.yaml
  kubectl -n kafka apply -f authentication.yaml

  kubectl -n kafka apply -f authorization-service.yaml
  kubectl -n kafka apply -f authorization.yaml
  ```

10. Create the Kafka cluster

  ```sh
  kubectl -n kafka apply -f kafka-cluster.yaml
  ```

11. Share access with the Kafka client applications (producer and consumer) by creating API keys for them (as Kubernetes `Secret` resources)

  ```sh
  kubectl -n kafka apply -f kafka-producer-api-key.yaml
  kubectl -n kafka apply -f kafka-consumer-api-key.yaml
  ```

12. Start the producer and attach to the interactive shell of the container

  ```sh
  kubectl -n kafka apply -f kafka-producer.yaml
  kubectl -n kafka attach -it pod/kafka-producer # <========= holds the shell
  ```

  Note: You may need to press <kbd>Enter</kbd> once, to see the prompt.

13. Produce a first "Hello" message

  ```sh
  > Hello # [Enter]
  ```

14. Start the consumer and watch the logs

  ```sh
  kubectl -n kafka apply -f kafka-consumer.yaml
  kubectl -n kafka logs -f pod/kafka-consumer # <========= holds the shell
  ```

## Future enhancements

Here are some enhancements/next steps to improve this PoC towards having a proper Authorino authorizer for the Kafka brokers.

1. Implement (in Java) an **Authorino Kafka Authorizer**, to replace the current pretend-to-be Keycloak workaround, and integrate it through [Strimzi Custom Authorization](https://strimzi.io/docs/operators/latest/using.html#type-KafkaAuthorizationCustom-reference).
2. Connect authorizer and Authorino directly, via gRPC, and avoid the reverse-proxy overhead.
3. Support for token refresh.
