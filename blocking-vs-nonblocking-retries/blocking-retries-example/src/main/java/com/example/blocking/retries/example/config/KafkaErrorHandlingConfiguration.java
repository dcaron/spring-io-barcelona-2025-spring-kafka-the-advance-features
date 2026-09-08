package com.example.blocking.retries.example.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.boot.kafka.autoconfigure.ConcurrentKafkaListenerContainerFactoryConfigurer;
import org.springframework.boot.kafka.autoconfigure.KafkaProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.ConcurrentKafkaListenerContainerFactory;
import org.springframework.kafka.config.ContainerCustomizer;
import org.springframework.kafka.core.ConsumerFactory;
import org.springframework.kafka.core.DefaultKafkaConsumerFactory;
import org.springframework.kafka.listener.ConcurrentMessageListenerContainer;
import org.springframework.kafka.listener.DefaultErrorHandler;
import org.springframework.util.backoff.FixedBackOff;

import java.net.SocketTimeoutException;

/**
 * This configuration class shows some custom error handling configurations.
 * Comment out the @Bean line to play around with the different settings
 * <p>
 * By default, the {@link DefaultErrorHandler} has a fixed {@link org.springframework.kafka.listener.SeekUtils.DEFAULT_BACK_OFF}
 * with {@link org.springframework.kafka.listener.SeekUtils#DEFAULT_MAX_FAILURES} of 10. And an interval of 0 ms
 * See {@link org.springframework.kafka.listener.KafkaMessageListenerContainer} method determineCommonErrorHandler()
 * To change this behaviour specify your {@link DefaultErrorHandler}
 * <p>
 * Unchecked exceptions (like RuntimeException) will trigger retries.
 * Checked exceptions (like IOException) will not trigger retries unless explicitly configured.
 */
@Configuration
public class KafkaErrorHandlingConfiguration {

    private static final Logger log = LoggerFactory.getLogger(KafkaErrorHandlingConfiguration.class);

    /**
     * Custom {@link FixedBackOff}
     */
//    @Bean
    public DefaultErrorHandler errorHandler() {
        // Retry 3 times with 2 seconds delay
        long interval = 2000L;
        int maxAttempts = 3;

        FixedBackOff fixedBackOff = new FixedBackOff(interval, maxAttempts);
        return new DefaultErrorHandler(fixedBackOff);
    }

    /**
     * Custom {@link FixedBackOff} and lambda expression for the {@link org.springframework.kafka.listener.ConsumerRecordRecoverer}
     * including retryable and non retryable exceptions
     */
//    @Bean
    public DefaultErrorHandler errorHandlerWithLamdaConsumerRecordRecoverer() {
        // Retry 3 times with 2 seconds delay
        long interval = 2000L;
        int maxAttempts = 3;

        FixedBackOff fixedBackOff = new FixedBackOff(interval, maxAttempts);
        DefaultErrorHandler errorHandler = new DefaultErrorHandler((consumerRecord, exception) -> {
            // logic to execute when all the retry attempts are exhausted
            log.error("Retry attempts are exhausted", exception);
        }, fixedBackOff);

        // Ignore retrying for specific exceptions
        errorHandler.addNotRetryableExceptions(NullPointerException.class);

        // Retry only for specific exceptions
        errorHandler.addRetryableExceptions(SocketTimeoutException.class);

        return errorHandler;
    }

    /**
     * Configure the KafkaListenerContainerFactory to enalbe the delivery attempt header.
     * The is no possibility to configure this via configuration properties in yml.
     * See:
     * https://docs.enterprise.spring.io/spring-kafka-dist/docs/3.0.18/reference/html/index.html#deliveryAttemptHeader
     */
    @Bean
    public ConcurrentKafkaListenerContainerFactory<?, ?> kafkaListenerContainerFactory(
            ConcurrentKafkaListenerContainerFactoryConfigurer configurer,
            ObjectProvider<ConsumerFactory<Object, Object>> kafkaConsumerFactory,
            ObjectProvider<ContainerCustomizer<Object, Object, ConcurrentMessageListenerContainer<Object, Object>>> kafkaContainerCustomizer,
            KafkaProperties properties) {
        ConcurrentKafkaListenerContainerFactory<Object, Object> factory = new ConcurrentKafkaListenerContainerFactory<>();
        configurer.configure(factory, kafkaConsumerFactory.getIfAvailable(() -> new DefaultKafkaConsumerFactory<>(
                properties.buildConsumerProperties())));
        kafkaContainerCustomizer.ifAvailable(factory::setContainerCustomizer);

        // This is required to get the delivery attempt header populated
        // so we can use the KafkaMessageHeaderAccessor accessor in the consumer
        factory.getContainerProperties().setDeliveryAttemptHeader(true);
        return factory;
    }

}
