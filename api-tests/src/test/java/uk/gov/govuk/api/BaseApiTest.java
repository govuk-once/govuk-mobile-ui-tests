package uk.gov.govuk.api;

import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import uk.gov.govuk.api.client.GovUkApiClient;

public abstract class BaseApiTest {

    protected static GovUkApiClient client;

    @BeforeAll
    static void setUp() {
        String baseUrl = System.getenv("BASE_URL");
        if (baseUrl == null || baseUrl.isBlank()) {
            baseUrl = "https://mobile.api.gov.uk";
        }
        client = new GovUkApiClient(baseUrl);
    }

    @AfterAll
    static void tearDown() {
        if (client != null) client.close();
    }
}
