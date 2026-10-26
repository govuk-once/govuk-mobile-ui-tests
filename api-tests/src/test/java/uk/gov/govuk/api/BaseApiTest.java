package uk.gov.govuk.api;

import io.restassured.RestAssured;
import io.restassured.builder.RequestSpecBuilder;
import io.restassured.filter.log.LogDetail;
import io.restassured.http.ContentType;
import io.restassured.specification.RequestSpecification;
import org.junit.jupiter.api.BeforeAll;

/**
 * Shared REST Assured setup.
 *
 * BASE_URL defaults to the API the GOV.UK app dev build uses (its BaseURL
 * setting), so these tests check the same data the app shows. Override it
 * with the BASE_URL environment variable to test another environment.
 */
public abstract class BaseApiTest {

    static final String DEFAULT_BASE_URL = "https://app.integration.publishing.service.gov.uk";
    static final String TOPICS_PATH = "/static/topics/list";

    protected static RequestSpecification api;

    @BeforeAll
    static void setUp() {
        String baseUrl = System.getenv("BASE_URL");
        if (baseUrl == null || baseUrl.isBlank()) {
            baseUrl = DEFAULT_BASE_URL;
        }

        api = new RequestSpecBuilder()
            .setBaseUri(baseUrl)
            .setAccept(ContentType.JSON)
            .build();

        // Print the request and response only when a check fails
        RestAssured.enableLoggingOfRequestAndResponseIfValidationFails(LogDetail.ALL);
    }
}