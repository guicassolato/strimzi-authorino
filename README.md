# Securing Kafka resources with Authorino

This is a proof of concept on securing Kafka resources – most notably Kafka topics – with [Authorino](https://github.com/kuadrant/authorino).

The implementation should work with Authorino v0.6.0 and relies on [Strimzi](https://strimzi.io) v0.23.0. It is quite limited regarding the types of permission that can be modeled. It is NOT meant for production.

**Characteristics of the implementation:**
- Relies on Strimzi support for Kafka broker OAuth authentication
- Relies on Strimzi support for Kafka broker authorization with Keycloak
- Does NOT use Keycloak
- Uses Authorino to issue OAuth access tokens and to provide the user permissions, the latter "pretending to be" Keycloak Authorization Service API
- Clients authentication is based on API keys, handled by Authorino, and exchanged for short-lived access tokens (Authorino Wristband tokens)
- Connection with the Kafka brokers is established bearing the Authorino Wristband token, which are verified and validated by the broker after fetching the JWKS from an Auhtorino endpoint
- Client permissions are stored in the annotations of Kubernetes `Secret`s that represent the API keys
- Kafka authorization request (based on Strimzi's `keycloak` authorization type) just bounces back permission claims already present in the Authorino Wristband token obtained and used in the authentication phase

**Limitations of the implementation:**
- Not very different from Kafka's standard ACL-based authorization, with the extra limitation that the API keys can only store permission info about one Kafka resource at a time.
- Authorino wristbands are only supplied on client startup, and neither the clients, nor the Kafka brokers refresh the token afterwards. Consequently, permissions last until the token expires or the restarts and obtains a new one again by exchanging with the API key.
- Cannot leverage authorization based on OPA policies, Authorino JSON pattern-matching authz or Kubernetes RBAC, that evaluate in request-time based upon combination of principal information (present in the access token) and resource/operation information, due to constraints of Strimzi's `keycloak` authorizer, which does not supply information about resources nor operations on the request for permission; rather, the authorizer can only provide a static list of permissions in the response.

#### Setup and Access sharing flows

![UML - Setup and Access sharing](http://www.plantuml.com/plantuml/png/jPLHRzD03CVVyocilZVPsCjqejEcCX1KGjEAc8JwShrupP745_cSLHtYkqFIQzQ4RMZGzQddkFRVlx-RE_UYMUgoY7nkgTAiIoWTEPEnAn64QumYiL8WpD7KR6a5CtsRQrYoov4zhAraS55BvjYIYo9jn37uZTTfQIaSHzVeNSq6mQq9UHHLciKQMsaIk6ANrWQv5vmwydKv28vczHAPKD33nTN7VfbBkdERNgHJrOksygDeCe4vIbt1P1BjrCBux8yUe4BUTcnTIuOarcYnZY9oWb3WhIZGbVsAxAqZ1NhNEJxnHXSO4qfoTxn4qSSBoYsbgbKtTNHhLmlo5Hgr883CUL60wGhZlEaN-plJn6tQD9LDcpHkUirme-177CS_cn2Zhnnv3C_NRBqiDQNjkVbOxsja1Pb8vLMIT0h73z-SJSr3MtLwT7gIjCUaFtNIbO-6j1g27NPGS8t6aR45Hbrqc3BL9iEMs6SmBO-N-k7Oth-Y7UtFdxMZ0TUHHaehPqaEpVeHcxzxHs493kl4jtzmmXIr5-IdF0Yp2jlotiRM1Vvl0lzjaJtqVGol0BEtEg51gD-hTNIKc0nD_XZXCFe-tJQo_sWkcWK8rnsXaDA7_nx5PD09X4yti_a-om-NNmxC88dNM1JZdDoQ4bSXsNHi714QIGoo-FrD2VDi5R5TPQ9QYSDvmnQrpxOlsKmpWZO6lM_UjSEhu8dDcZ9gGQZ2tT248SVDFf7jtipHCCg2D96JTaBVxayxUyidgJqowH9L2EwA3j8u25CWhh96fLYwGOgha4CF60M9xz0Rjak46xQ2eyFz4OUpFuhkQfUa0kcGt3FghQviD_MuEVpEE7kX5IRSo0Ur8XJzNoiw3wvHfmUq8CXxte9fIFgx1Q7SdWNdI6bT5hy0)

#### Kafka producer flow

![UML - Kafka producer](http://www.plantuml.com/plantuml/png/VPBHJzim4CRV_LUSyhnIfhqW2o5OXxQf3o2OGDCwJSQvKYk9dTrTGDsq_trEGzoaHBp5b-_y-RlxdRCOagOg5HVEruPC1LNmmMueL0X23IebJag4QmfvO-FHM0a4l6MJLyw_7BCRvD2GHGZF7YbJyIvnrjN6IzzAe-8YU6wgWsAsR1wGF0eoN5n_7LzpwP_2TbIvQ6GJoFamgYxDkZ1AzQumE-jQGSCD_cwG1Px9iJmOdoiV187SuqOqVBxy1XkHMi_dc3_YKT5UTCHFTYwXGB_oBtv_ZBZWTVl2vULtE3MrczKlRZFZPWLkprHd6RtJ8q7llj6BiqPGfH-7gZjJkZmgMWE8busKASjjKzVbzZ1AYUkOn37hNHIEMKpVFTj_1PVRVJvzSdpoORuxHdLwOWmvJzUlV4suHYBCVpMCv4s56dOzAVpA4tTr2RMpEiSgh3pRK2DhM12seJuXMt8F2FVa1DES4YN3nNMx1DtIuj7AQ5ttANcd6iZlaDnwEt_g1paXJIuQhfPJdhq2AcGsZpZophvWMOPCbI7KyFwO5NHjKx2P8JLHEDZJzTLjGgwL3P2p6xJ5A-G-eY4aE4rhELC0awZrZHW5qwJjvvI0syC4y1PqDLBbc5tmF0xqus_M8P3fRCz0zYxh88ZLIGgoVp_x76a3QQH334mSoyWTfzQ_Q6StbBsMt0gXgTxQxIGg5ukbEe-UJLN-1m00)

#### Kafka consumer flow

![UML - Kafka consumer](http://www.plantuml.com/plantuml/png/RLBTRjCm5BxtKnpbcYv3t4pMD6sC2L0lLdLe2564NEUqjPBOvjZkL13lZjEaRZno5vzyv-VxkNLUa0zjmrojj1KaMcYDDd97faNm590nhto3S6-q2sry2kaDWJiuKRLA3yzYYSu4aWZcHICLBCxoIYehj8S5cIf8fAmupCkBnJoiaJHwT72t-9oFUT1xSyWgTy7l32bjikfSR6h1s6a1p6xwLk2mn5y1dOSNKiwlXQwODXw1r7RdENny-08xxoqlIwosU55tWoxSNfRUrAXNUjZtMtXbDEykd3zyWsjXrKmEssP2pMeytB1-PToTZWH-_4OTBnKUMVhn6lKi6bL5HBS0uh0CcRWy1MkRmsig3MuY4-KSFr9naOiuTS_ENqPLyioFNrrUlIkFpuXE9qQIPHg_qfPmWqHO_GmEIOiMEHnx4lcL9jVNlR5AyWfRiz9E6elndW_e9AarmX95bVH9GHWRrdi8lFkfKVhCfg-9SOyQmP-HrEPGxWS1fw1f2uV7-VJElWOjEYUso1fZBBozT0nwo5IWn3WP4JZoOl7ub6BLmKQnaZkKzN-nUe-2aE0wINyJ1qx7QMZ429XEquGcQMngcWwMHMfZZbHK8oVq_K_HsrpmuknpyQReZOxLpEdYxuzq_qdbiPH9TX7boBRYbCNtdMOPRCBQz9bC7DrVVCAcCGMxZVD3s_m3)

## Instructions

Steps 1-5 below are for installing and deploying Authorino on a Kubernetes cluster started locally with Kind, using some Authorino trial tooling from the Authorino repo. If you prefer handling Authorino installation and deployment by yourself, perhaps on another Kubernetes server of preference where you want to try this PoC, you can skip directly to step 6. In this case, make sure to create on your Kubernetes server a `Namespace` named `kafka`, where Authorino and all the other resources involved in the PoC must be created.

1. Start a local Kubernetes cluster with Kind

  ```sh
  kind create cluster --name strimzi-authorino-demo
  ```

2. Install the Authorino Operator

  ```sh
  TMP_DIR=$(mktemp -d) && cd $TMP_DIR
  git clone --depth 1 --branch main https://github.com/Kuadrant/authorino-operator.git .
  kubectl create namespace authorino-operator && make install deploy
  rm -rf $TMP_DIR
  ```

3. Create the namespace for the project

  ```sh
  kubectl create namespace kafka
  ```

4. Install cert-manager and Authorino CRD

  ```sh
  TMP_DIR=$(mktemp -d) && cd $TMP_DIR
  git clone --depth 1 --branch main https://github.com/kuadrant/authorino.git .
  make cert-manager # installs https://github.com/jetstack/cert-manager - skip it if already installed
  make certs NAMESPACE=kafka
  rm -rf $TMP_DIR
  ```

5. Deploy Authorino

  ```sh
  kubectl -n kafka apply -f -<<EOF
  apiVersion: operator.authorino.kuadrant.io/v1beta1
  kind: Authorino
  metadata:
    name: authorino
  spec:
    image: quay.io/3scale/authorino:latest
    clusterWide: false
    listener:
      tls:
        enabled: true
        certSecretRef:
          name: authorino-server-cert
    oidcServer:
      tls:
        enabled: true
        certSecretRef:
          name: authorino-oidc-server-cert
  EOF
  ```

6. Clone this repo

  ```sh
  git clone git@github.com:guicassolato/strimzi-authorino.git && cd strimzi-authorino
  ```

7. Setup the Envoy proxy

  ```sh
  kubectl -n kafka apply -f envoy-proxy.yaml
  ```

8. Install the Strimzi operator

  ```sh
  kubectl -n kafka apply -f strimzi-install.yaml
  ```

9. Create the Authorino `AuthConfig`s and Kubernetes `Service`s for authentication and authorization

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
2. Support for token refresh.
