// Moves to the next topic fetched by fetch-topics.js. Sets output.currentTopic
// (for messages) and output.currentTopicPattern (the title with regex
// characters escaped, because Maestro text selectors are regular expressions).

var title = output.topicTitles[output.topicIndex];

output.currentTopic = title;
output.currentTopicPattern = title.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
output.topicIndex = output.topicIndex + 1;

console.log('Checking topic ' + output.topicIndex + '/' + output.topicCount + ': ' + title);