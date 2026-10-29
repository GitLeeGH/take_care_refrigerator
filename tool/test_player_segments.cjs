// Run the actual embedded JavaScript against an official-API-shaped fake player.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const testVideo = process.argv[2] || 'rLEyOHvGb1Y';
assert.match(testVideo, /^[A-Za-z0-9_-]{11}$/);
const source = fs.readFileSync('lib/src/services/original_video.dart', 'utf8');
const script = source.split('<div id="player"></div><script>')[1].split('</script>')[0]
  .replaceAll('$id', testVideo).replaceAll('$origin', 'https://com.tcf.take_care_refrigerator.dev');
let state = 2, time = 0, video = testVideo;
const calls = [];
const player = {
  getPlayerState: () => state, getCurrentTime: () => time,
  getVideoUrl: () => `https://www.youtube.com/watch?v=${video}`,
  cueVideoById: o => calls.push(['cue', {...o}]),
  loadVideoById: o => calls.push(['load', {...o}]),
  pauseVideo: () => calls.push(['pause']), destroy: () => calls.push(['destroy']),
  playVideo: () => calls.push(['play']),
};
let timerCleared=false;
const context = {URL, setInterval:()=>1,clearInterval:()=>{timerCleared=true;},document: {hidden: false, addEventListener: () => {}}, PlayerStatus: {postMessage: () => {}}};
vm.createContext(context); vm.runInContext(script, context); context.player = player;
context.setRecipeSegment(20, 25, false, true);
assert.deepEqual(calls.pop(), ['cue', {videoId: video, startSeconds: 20, endSeconds: 25}]);
state = 1; context.setRecipeSegment(30, 35, true, true);
assert.deepEqual(calls.pop(), ['load', {videoId: video, startSeconds: 30, endSeconds: 35}]);
time = 35; context.recipePlayerState({data: 0}); assert.equal(calls.pop()[0], 'load');
context.setRecipeSegment(30, 35, false, false);
context.recipePlayerState({data: 0}); assert.equal(calls.length, 0);
context.setRecipeSegment(30, 35, true, false); context.pauseVideo(); calls.length = 0;
context.recipePlayerState({data: 0}); assert.equal(calls.length, 0);
context.resumeRecipePlayback(); context.document.hidden = true;
context.recipePlayerState({data: 0}); assert.equal(calls.length, 0);
context.document.hidden = false; video = 'another1234';
context.recipePlayerState({data: 0}); assert.equal(calls.length, 0);
video = testVideo; time = 20; context.recipePlayerState({data: 0}); assert.equal(calls.length, 0);
context.setRecipeSegment(null, null, false, true);
assert.deepEqual(calls.pop(), ['load', {videoId: video, startSeconds: 20}]);
context.destroyRecipePlayer(); assert.equal(calls.pop()[0], 'destroy');
assert.equal(timerCleared,true);
context.recipePlayerState({data: 0}); assert.equal(calls.length, 0);
console.log('Player segment state tests passed: paused/playing, repeat/off, exit, hidden, stale end, foreign video, clear, destroy');
context.playRecipeVideo(); assert.equal(calls.length, 0);
context.resumeRecipePlayback(); context.playRecipeVideo(); assert.equal(calls.pop()[0], 'play');
context.setRecipeSegment(19,21,false,false);
assert.equal(calls.length,0);
context.playRecipeVideo(true);
assert.deepEqual(calls.pop(), ['load', {videoId:video,startSeconds:19,endSeconds:21}]);
context.document.hidden = true; context.playRecipeVideo(); assert.equal(calls.length, 0);
context.document.hidden = false; context.pauseVideo(); calls.length = 0;
context.playRecipeVideo(); assert.equal(calls.length, 0);
let events, messages = [];
context.YT = {Player: function(_, options) { events = options.events; return player; }};
context.PlayerStatus.postMessage = message => messages.push(message);
context.onYouTubeIframeAPIReady();
events.onAutoplayBlocked(); assert.equal(messages.pop(), 'blocked');
events.onStateChange({data: 2}); assert.equal(messages.pop(), 'state:2');
console.log('Explicit playback, hidden/suspended guards and autoplay-blocked event tests passed');
context.resumeRecipePlayback(); state=1; time=24.8;
context.setRecipeSegment(20,25,false,false);
context.checkRecipeBoundary(); assert.equal(calls.pop()[0],'pause');
assert.equal(messages.pop(),'segment-ended');
context.checkRecipeBoundary(); assert.equal(calls.length,0);
context.playRecipeVideo(true); calls.length=0;
context.setRecipeSegment(20,25,true,false);
context.checkRecipeBoundary(); assert.equal(calls.length,0);
context.setRecipeSegment(20,25,false,false); context.document.hidden=true;
context.checkRecipeBoundary(); assert.equal(calls.length,0);
context.document.hidden=false; context.pauseVideo(); calls.length=0;
context.checkRecipeBoundary(); assert.equal(calls.length,0);
context.resumeRecipePlayback(); video='another1234';
context.checkRecipeBoundary(); assert.equal(calls.length,0);
video=testVideo; time=22;
context.checkRecipeBoundary(); assert.equal(calls.length,0);
time=25; context.checkRecipeBoundary(); assert.equal(calls.length,0);
console.log('Frame-hold boundary tests passed: pause once, replay, repeat, hidden, exit, wrong video, outside boundary, timer cleanup');

// Flutter step-change flow: update bounds without cue, then explicit bounded
// load. Covers both the frame-held pause and the native endSeconds fallback.
for (const previousState of [2, 0, 1]) {
  state=previousState; calls.length=0;
  context.setRecipeSegment(30,35,false,false);
  assert.equal(calls.length,0);
  context.playRecipeVideo(true);
  assert.deepEqual(calls.pop(), ['load',{videoId:testVideo,startSeconds:30,endSeconds:35}]);
  assert.equal(calls.length,0);
  context.setRecipeSegment(20,25,false,false);
  context.playRecipeVideo(true);
  assert.deepEqual(calls.pop(), ['load',{videoId:testVideo,startSeconds:20,endSeconds:25}]);
}
context.pauseVideo(); calls.length=0;
context.setRecipeSegment(30,35,false,false); context.playRecipeVideo(true);
assert.equal(calls.length,0);
context.resumeRecipePlayback(); context.document.hidden=true;
context.playRecipeVideo(true); assert.equal(calls.length,0);
console.log('Explicit next/previous after paused, ended, playing states and exit/hidden guards passed');
