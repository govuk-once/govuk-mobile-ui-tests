package uk.gov.govuk.api.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

/** One entry from the topics list the app shows on its home screen. */
@JsonIgnoreProperties(ignoreUnknown = true)
public class Topic {

    private String ref;
    private String title;
    private String description;

    public Topic() {}

    public String getRef() { return ref; }
    public void setRef(String ref) { this.ref = ref; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
}