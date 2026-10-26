package uk.gov.govuk.api;

import io.restassured.http.ContentType;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import uk.gov.govuk.api.model.Topic;

import java.util.Arrays;
import java.util.List;

import static io.restassured.RestAssured.given;
import static io.restassured.module.jsv.JsonSchemaValidator.matchesJsonSchemaInClasspath;
import static org.assertj.core.api.Assertions.assertThat;

/** Contract tests for the topics list the app loads on its home screen. */
@Tag("contract")
class TopicsApiTest extends BaseApiTest {

    private static final List<String> EXPECTED_TOPICS = List.of(
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

    @Test
    void topics_returns200WithJson() {
        given().spec(api)
        .when()
            .get(TOPICS_PATH)
        .then()
            .statusCode(200)
            .contentType(ContentType.JSON);
    }

    @Test
    void topics_matchesJsonSchema() {
        given().spec(api)
        .when()
            .get(TOPICS_PATH)
        .then()
            .statusCode(200)
            .body(matchesJsonSchemaInClasspath("schema/topics-schema.json"));
    }

    @Test
    void topics_containsAllExpectedTopics() {
        List<String> titles =
            given().spec(api)
            .when()
                .get(TOPICS_PATH)
            .then()
                .statusCode(200)
                .extract().jsonPath().getList("title", String.class);

        assertThat(titles).containsAll(EXPECTED_TOPICS);
    }

    @Test
    void topics_haveUniqueRefsAndTitles() {
        Topic[] topics =
            given().spec(api)
            .when()
                .get(TOPICS_PATH)
            .then()
                .statusCode(200)
                .extract().as(Topic[].class);

        assertThat(topics).isNotEmpty();
        assertThat(Arrays.stream(topics).map(Topic::getRef)).doesNotHaveDuplicates();
        assertThat(Arrays.stream(topics).map(Topic::getTitle)).doesNotHaveDuplicates();
    }
}