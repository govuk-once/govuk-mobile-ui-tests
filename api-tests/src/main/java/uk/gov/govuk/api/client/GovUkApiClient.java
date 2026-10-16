package uk.gov.govuk.api.client;

import com.microsoft.playwright.APIRequest;
import com.microsoft.playwright.APIRequestContext;
import com.microsoft.playwright.APIResponse;
import com.microsoft.playwright.Playwright;
import com.microsoft.playwright.options.RequestOptions;

import java.util.Map;

/**
 * HTTP client wrapping Playwright's APIRequestContext.
 * No browser is launched — this is a pure HTTP client.
 */
public class GovUkApiClient implements AutoCloseable {

    private final Playwright playwright;
    private final APIRequestContext requestContext;

    public GovUkApiClient(String baseUrl) {
        this.playwright = Playwright.create();
        this.requestContext = playwright.request().newContext(
            new APIRequest.NewContextOptions()
                .setBaseURL(baseUrl)
                .setExtraHTTPHeaders(Map.of(
                    "Accept", "application/json"
                ))
        );
    }

    public APIResponse getTopics() {
        return requestContext.get("/topics");
    }

    public APIResponse get(String path) {
        return requestContext.get(path);
    }

    public APIResponse get(String path, RequestOptions options) {
        return requestContext.get(path, options);
    }

    public APIResponse post(String path, Object data) {
        return requestContext.post(path, RequestOptions.create().setData(data));
    }

    @Override
    public void close() {
        if (requestContext != null) requestContext.dispose();
        if (playwright != null) playwright.close();
    }
}
