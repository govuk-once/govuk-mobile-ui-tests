// Fetches the topics list from the same API the GOV.UK app uses and stores
// the titles for the flow to check on screen, one by one (see next-topic.js).
// Override the API with -e API_BASE_URL=... (defaults to the dev build's API).

var baseUrl = 'https://app.integration.publishing.service.gov.uk';
if (typeof API_BASE_URL !== 'undefined' && API_BASE_URL && API_BASE_URL !== 'undefined') {
  baseUrl = API_BASE_URL;
}

var url = baseUrl + '/static/topics/list';
var response = http.get(url);

if (response.status !== 200) {
  throw new Error('GET ' + url + ' returned HTTP ' + response.status);
}

var topics = json(response.body);
if (!topics || topics.length === 0) {
  throw new Error('GET ' + url + ' returned no topics');
}

output.topicTitles = topics.map(function (topic) { return topic.title; });
output.topicCount = output.topicTitles.length;
output.topicIndex = 0;

console.log('Topics from API (' + output.topicCount + '): ' + output.topicTitles.join(', '));