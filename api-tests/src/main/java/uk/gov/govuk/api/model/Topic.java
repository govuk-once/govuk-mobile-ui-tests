package uk.gov.govuk.api.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

@JsonIgnoreProperties(ignoreUnknown = true)
public class Topic {

    private String title;
    private String ref;

    public Topic() {}

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getRef() { return ref; }
    public void setRef(String ref) { this.ref = ref; }
}
