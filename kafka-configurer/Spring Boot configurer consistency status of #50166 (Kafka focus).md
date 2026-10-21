# Spring Boot configurer consistency: status of #50166 (Kafka focus)

Oct 21, 2026 · @David

## Problem

Spring Boot's documented way to customize a messaging component is to define your own factory bean and call the auto-configured configurer on it, for example `ConcurrentKafkaListenerContainerFactoryConfigurer.configure(...)`. The result should match what Boot builds, plus your changes.

For Kafka and Rabbit it doesn't. Some customizers are applied in Boot's own bean methods instead of inside `configure(...)`:

- `ContainerCustomizer`
- `RabbitTemplateCustomizer`
- for Kafka, the consumer-factory customizers that add Micrometer metrics

An application that defines a custom or second factory therefore silently loses that behaviour, including observability. #50166 proposes making every configurer apply all of it.

## Summary

None of the inconsistencies described in [spring-boot #50166](https://github.com/spring-projects/spring-boot/issues/50166) are fixed on `main` (4.2.0-SNAPSHOT) as of 21 October 2026. The issue is assigned, but no commit references it.

The new `KafkaConfigBuilder` (4.2.0-M2) is related progress. It makes Kafka client properties easy to reproduce, but it does not address the listener-factory and factory-customizer gaps that cause lost metrics or customizations in hand-built beans.

Until a fix lands, apply the missing customizers yourself (see Recommended workaround).

## Status per area in #50166

Checked against `main` and `4.1.x` source and commit history on 21 October 2026.

| Area | Gap named in #50166 | Status on `main` |
| --- | --- | --- |
| Kafka | `ContainerCustomizer` applied in the bean method, outside `ConcurrentKafkaListenerContainerFactoryConfigurer.configure(...)` | Unchanged |
| Rabbit | `ContainerCustomizer` (simple and direct listener factories) applied outside the configurer | Unchanged; code moved to the new `spring-boot-rabbitmq` module (15 July 2026) |
| Rabbit | `RabbitTemplateCustomizer`s applied outside `RabbitTemplateConfigurer` | Unchanged, same module move |
| JMS, Redis | None, already consistent | Unchanged |
| `RestClientBuilderConfigurer` | None, already consistent | Unchanged |
| `RestTemplateBuilderConfigurer` | None, already consistent | RestTemplate support deprecated (25 July 2026), so it drops out of scope |

## KafkaConfigBuilder: an improvement, not a fix

`KafkaConfigBuilder` ([gh-51769](https://github.com/spring-projects/spring-boot/issues/51769), commit `d031631709`, `@since 4.2.0`) builds the Kafka client property maps for consumer, producer, admin and streams. It is now the only place Boot maps `spring.kafka.*` to client config.

**What it fixes**

- `withConnectionDetails(...)` applies `KafkaConnectionDetails`: bootstrap servers, security protocol and SSL bundle.
- A hand-built `DefaultKafkaConsumerFactory` no longer silently misses connection details from Docker Compose or Testcontainers, or SSL bundle wiring.
- `KafkaProperties.build*Properties()` is deprecated in its favour.

**What it does not fix**

- `ContainerCustomizer` is still applied in the `kafkaListenerContainerFactory` bean method, after `configurer.configure(...)`. This is the gap #50166 names.
- `DefaultKafkaConsumerFactoryCustomizer`s are still applied in the `kafkaConsumerFactory` bean method. `KafkaMetricsAutoConfiguration` attaches `MicrometerConsumerListener` (Kafka client metrics) this way, so a hand-built consumer factory still has no client metrics.

Listener observation (`spring.kafka.listener.observation-enabled`) and a custom `KafkaListenerObservationConvention` are mapped inside the configurer, so listener tracing does survive. The likely sources of the observability loss reported in #50166 are client metrics or a missing `ContainerCustomizer`. The issue does not say which.

## Release outlook

`KafkaConfigBuilder` ships in Spring Boot 4.2.0. It is in the `v4.2.0-M2` tag (late September 2026), not in M1, and not on `4.1.x`. A backport is unlikely, because it adds API and deprecates existing methods.

| Item | Where it stands | Expected in |
| --- | --- | --- |
| `KafkaConfigBuilder` | In 4.2.0-M2 | 4.2.0 GA |
| #50166 fix (Kafka, Rabbit) | Assigned, no commits | Not yet known: 4.2.0 RC if it lands soon, otherwise 4.3 |

No official 4.2.0 GA date was found. Spring Boot's six-month cadence (4.0 in November 2025, 4.1 in May 2026) points to November 2026 for 4.2 and around May 2027 for 4.3. These are expectations, not published dates.

## Recommended workaround

When you define your own Kafka consumer factory or listener container factory, re-apply what the auto-configuration applies outside the configurer. The example below targets 4.2. On 4.1, replace the `KafkaConfigBuilder` call with `properties.buildConsumerProperties()` and apply the connection details yourself.

```java
@Bean
ConcurrentKafkaListenerContainerFactory<Object, Object> myListenerFactory(
        ConcurrentKafkaListenerContainerFactoryConfigurer configurer,
        KafkaProperties properties,
        KafkaConnectionDetails connectionDetails,
        ObjectProvider<DefaultKafkaConsumerFactoryCustomizer> consumerFactoryCustomizers,
        ObjectProvider<ContainerCustomizer<Object, Object, ConcurrentMessageListenerContainer<Object, Object>>> containerCustomizer) {

    // 1. Client properties exactly as Boot builds them (4.2+)
    Map<String, Object> config = KafkaConfigBuilder.of(properties)
        .consumer()
        .withConnectionDetails(connectionDetails)
        .build();
    // ...adjust config here if needed

    // 2. Consumer factory plus Boot's factory customizers (includes Micrometer client metrics)
    DefaultKafkaConsumerFactory<Object, Object> consumerFactory = new DefaultKafkaConsumerFactory<>(config);
    consumerFactoryCustomizers.orderedStream().forEach((c) -> c.customize(consumerFactory));

    // 3. Listener factory via the configurer, then the container customizer it does not apply
    ConcurrentKafkaListenerContainerFactory<Object, Object> factory = new ConcurrentKafkaListenerContainerFactory<>();
    configurer.configure(factory, consumerFactory);
    containerCustomizer.ifAvailable(factory::setContainerCustomizer);
    return factory;
}
```

For Rabbit, apply the same pattern: after `configurer.configure(...)`, set the `ContainerCustomizer` on the listener factory, and run the `RabbitTemplateCustomizer`s on a hand-built `RabbitTemplate`.

## Suggestions for the maintainers

1. Move `ContainerCustomizer` handling into `ConcurrentKafkaListenerContainerFactoryConfigurer` and the Rabbit listener configurers, so `configure(...)` alone reproduces the auto-configured factory.
2. Apply `RabbitTemplateCustomizer`s inside `RabbitTemplateConfigurer`.
3. Offer a single entry point for an auto-configured-equivalent `DefaultKafkaConsumerFactory`/`DefaultKafkaProducerFactory` that applies both `KafkaConfigBuilder` and the factory customizers. Without it, client metrics stay easy to lose.
4. Document the contract explicitly: "`configure(...)` yields the same result as the auto-configured bean." Add a test per configurer that compares the two.
5. Aim for 4.2.0, alongside `KafkaConfigBuilder` and the new `spring-boot-rabbitmq` module, so users meet one consistent model.

## References

**Issues**

- [#50166 Make use of configurer pattern consistent](https://github.com/spring-projects/spring-boot/issues/50166)
- [#51769 KafkaConfigBuilder](https://github.com/spring-projects/spring-boot/issues/51769)
- [#5138 Origin of the configurer pattern](https://github.com/spring-projects/spring-boot/issues/5138)

**Commits**

- [d031631709 Introduce KafkaConfigBuilder (15 Sep 2026)](https://github.com/spring-projects/spring-boot/commit/d031631709)
- [dcbb307d3e Dedicated KafkaAdmin for listener and template (15 Sep 2026)](https://github.com/spring-projects/spring-boot/commit/dcbb307d3e)
- [f48cc3ac10 Move Spring AMQP 0.9 support to spring-boot-rabbitmq (15 Jul 2026)](https://github.com/spring-projects/spring-boot/commit/f48cc3ac10)
- [3959c56bdd Deprecate RestTemplate support (25 Jul 2026)](https://github.com/spring-projects/spring-boot/commit/3959c56bdd)
- [51ffc529ba Baseline referenced in #50166 (22 Apr 2026)](https://github.com/spring-projects/spring-boot/commit/51ffc529ba258f7c0138446eb902dea894a89bfa)

**Source on `main`**

- [KafkaAnnotationDrivenConfiguration.java](https://github.com/spring-projects/spring-boot/blob/main/module/spring-boot-kafka/src/main/java/org/springframework/boot/kafka/autoconfigure/KafkaAnnotationDrivenConfiguration.java)
- [ConcurrentKafkaListenerContainerFactoryConfigurer.java](https://github.com/spring-projects/spring-boot/blob/main/module/spring-boot-kafka/src/main/java/org/springframework/boot/kafka/autoconfigure/ConcurrentKafkaListenerContainerFactoryConfigurer.java)
- [KafkaConfigBuilder.java](https://github.com/spring-projects/spring-boot/blob/main/module/spring-boot-kafka/src/main/java/org/springframework/boot/kafka/autoconfigure/KafkaConfigBuilder.java)
- [KafkaAutoConfiguration.java](https://github.com/spring-projects/spring-boot/blob/main/module/spring-boot-kafka/src/main/java/org/springframework/boot/kafka/autoconfigure/KafkaAutoConfiguration.java)
- [KafkaMetricsAutoConfiguration.java](https://github.com/spring-projects/spring-boot/blob/main/module/spring-boot-kafka/src/main/java/org/springframework/boot/kafka/autoconfigure/metrics/KafkaMetricsAutoConfiguration.java)
- [RabbitAnnotationDrivenConfiguration.java](https://github.com/spring-projects/spring-boot/blob/main/module/spring-boot-rabbitmq/src/main/java/org/springframework/boot/rabbitmq/autoconfigure/RabbitAnnotationDrivenConfiguration.java)
- [RabbitAutoConfiguration.java](https://github.com/spring-projects/spring-boot/blob/main/module/spring-boot-rabbitmq/src/main/java/org/springframework/boot/rabbitmq/autoconfigure/RabbitAutoConfiguration.java)

**Releases**

- [Tag v4.2.0-M2](https://github.com/spring-projects/spring-boot/releases/tag/v4.2.0-M2)
- [InfoQ Spring news roundup, week of 21 September 2026](https://infoq.com/news/2026/09/spring-news-roundup-sep21-2026)
