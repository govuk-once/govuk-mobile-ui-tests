package uk.gov.govuk.api;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.microsoft.playwright.APIResponse;
import com.networknt.schema.JsonSchema;
import com.networknt.schema.JsonSchemaFactory;
import com.networknt.schema.SpecVersion;
import com.networknt.schema.ValidationMessage;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import uk.gov.govuk.api.model.Topic;

import java.io.InputStream;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import static org.assertj.core.api.Assertions.assertThat;

class TopicsApiTest extends BaseApiTest {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    @Test
    void getTopics_returns200() {
        APIResponse response = client.getTopics();
        assertThat(response.status()).isEqualTo(200);
    }

    @Test
    void getTopics_matchesJsonSchema() throws Exception {
        APIResponse response = client.getTopics();
        assertThat(response.status()).isEqualTo(200);

        JsonSchemaFactory factory = JsonSchemaFactory.getInstance(SpecVersion.VersionFlag.V7);
        try (InputStream schemaStream = getClass().getResourceAsStream("/schema/topics-schema.json")) {
            JsonSchema schema = factory.getSchema(schemaStream);
            JsonNode responseJson = MAPPER.readTree(response.body());
            Set<ValidationMessage> errors = schema.validate(responseJson);
            assertThat(errors)
                .as("JSON schema validation errors: %s", errors)
                .isEmpty();
        }
    }

    @Test
    void getTopics_containsAllExpectedTopics() throws Exception {
        APIResponse response = client.getTopics();
        assertThat(response.status()).isEqualTo(200);

        List<Topic> topics = MAPPER.readValue(
            response.body(),
            new TypeReference<List<Topic>>() {}
        );

        List<String> titles = topics.stream()
            .map(Topic::getTitle)
            .collect(Collectors.toList());

        assertThat(titles).contains(
            "Benefits",
            "Business",
            "Care",
            "Driving and transport",
            "Employment",
            "Health and disability",
            "Money and tax",
            "Parenting and guardianship",
            "Retirement",
            "Studying and training",
            "Travel abroad"
        );
    }

    /**
     * Fetches live topics and prints them as EXPECTED_TOPICS env var for the Maestro e2e harness.
     * Run via: mvn test -Dtest.tags=e2e
     */
    @Tag("e2e")
    @Test
    void exportTopicsForMaestroE2E() throws Exception {
        APIResponse response = client.getTopics();
        assertThat(response.status()).isEqualTo(200);

        List<Topic> topics = MAPPER.readValue(
            response.body(),
            new TypeReference<List<Topic>>() {}
        );

        assertThat(topics).isNotEmpty();

        String csv = topics.stream()
            .map(Topic::getTitle)
            .collect(Collectors.joining(","));

        // Captured by run-e2e.sh and exported as env var for Maestro
        System.out.println("EXPECTED_TOPICS=" + csv);
    }
}
