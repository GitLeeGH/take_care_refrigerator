import 'recipe_draft.dart';

enum OriginalVideoKind { youtube, instagram }

class OriginalVideo {
  const OriginalVideo(this.kind, this.id);
  final OriginalVideoKind kind;
  final String id;
  Uri? get thumbnailUrl =>
      kind == OriginalVideoKind.youtube &&
          RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)
      ? Uri.https('i.ytimg.com', '/vi/$id/hqdefault.jpg')
      : null;
  Uri get url => Uri.parse(
    kind == OriginalVideoKind.youtube
        ? 'https://www.youtube.com/watch?v=$id'
        : 'https://www.instagram.com/reel/$id/',
  );
  static OriginalVideo? parse(String input) {
    final youtube = YoutubeSource.parse(input);
    if (youtube != null)
      return OriginalVideo(OriginalVideoKind.youtube, youtube.videoId);
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443) ||
        !const {'instagram.com', 'www.instagram.com'}.contains(uri.host))
      return null;
    final parts = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    if (parts.length != 2 ||
        parts.first != 'reel' ||
        !RegExp(r'^[A-Za-z0-9_-]{5,64}$').hasMatch(parts[1]) ||
        uri.path.contains('//'))
      return null;
    return OriginalVideo(OriginalVideoKind.instagram, parts[1]);
  }
}

String youtubePlayerError(int code) => switch (code) {
  100 => '삭제되었거나 비공개인 영상입니다. 원본에서 확인해 주세요.',
  101 || 150 => '제작자가 앱 안 재생을 허용하지 않았어요. 원본에서 확인해 주세요.',
  153 => 'YouTube가 앱 재생 요청을 확인하지 못했어요. 원본에서 확인해 주세요.',
  _ => '앱 안에서 재생하지 못했어요. 원본에서 확인해 주세요.',
};

String youtubePlayerHtml(String id, String origin) {
  if (!RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id) ||
      !const {
        'https://com.tcf.take_care_refrigerator',
        'https://com.tcf.take_care_refrigerator.dev',
      }.contains(origin)) {
    throw ArgumentError('Invalid player identity');
  }
  return '''<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>html,body,#player{margin:0;width:100%;height:100%;background:#000}</style></head><body>
<div id="player"></div><script>
var player, recipeSegment=null, recipeRepeat=false, recipeActive=true, recipeHeld=false;
// Pause shortly before native ENDED, which may clear the displayed frame.
// Native endSeconds remains the fallback if the WebView timer is delayed.
var recipeBoundaryTimer=setInterval(checkRecipeBoundary,100);
function checkRecipeBoundary(){
  if(!recipeActive||document.hidden||recipeRepeat||recipeHeld||!recipeSegment||!player||!player.getPlayerState||player.getPlayerState()!==1)return;
  var time=player.getCurrentTime();
  var url=new URL(player.getVideoUrl());
  var margin=Math.min(0.25,(recipeSegment.end-recipeSegment.start)/4);
  if(url.searchParams.get('v')!=='$id'||time<recipeSegment.end-margin||time>=recipeSegment.end)return;
  recipeHeld=true;
  player.pauseVideo();
  PlayerStatus.postMessage('segment-ended');
}
function pauseVideo(){recipeActive=false;if(player&&player.pauseVideo)player.pauseVideo();}
function resumeRecipePlayback(){recipeActive=true;}
function playRecipeVideo(fromStart){
  if(!recipeActive||document.hidden||!player)return;
  recipeHeld=false;
  if(fromStart&&recipeSegment){
    player.loadVideoById({videoId:'$id',startSeconds:recipeSegment.start,endSeconds:recipeSegment.end});
  }else if(player.playVideo){player.playVideo();}
}
function destroyRecipePlayer(){recipeActive=false;recipeRepeat=false;recipeSegment=null;clearInterval(recipeBoundaryTimer);if(player&&player.destroy)player.destroy();}
function setRecipeSegment(start,end,repeat,seek){
  var valid=Number.isFinite(start)&&Number.isFinite(end)&&start>=0&&end>start&&end<=86400;
  recipeSegment=valid?{start:start,end:end}:null;
  recipeRepeat=valid&&repeat===true;
  if(seek)recipeHeld=false;
  if(!player||!player.getPlayerState||!seek)return;
  var playing=recipeActive&&!document.hidden&&player.getPlayerState()===1;
  var options={videoId:'$id',startSeconds:valid?start:player.getCurrentTime()};
  if(valid)options.endSeconds=end;
  // seekTo cancels endSeconds; re-cue paused video or load playing video instead.
  if(playing)player.loadVideoById(options);else player.cueVideoById(options);
}
function recipePlayerState(e){
  PlayerStatus.postMessage('state:'+e.data);
  if(e.data===1&&(!recipeActive||document.hidden)){player.pauseVideo();return;}
  if(e.data!==0||!recipeActive||document.hidden||!recipeRepeat||!recipeSegment)return;
  var time=player.getCurrentTime();
  var url=new URL(player.getVideoUrl());
  if(url.searchParams.get('v')!=='$id'||time<recipeSegment.end-0.3||time>recipeSegment.end+1)return;
  player.loadVideoById({videoId:'$id',startSeconds:recipeSegment.start,endSeconds:recipeSegment.end});
}
function onYouTubeIframeAPIReady(){player=new YT.Player('player',{videoId:'$id',width:'100%',height:'100%',
playerVars:{autoplay:0,playsinline:1,origin:'$origin'},events:{
onReady:function(){PlayerStatus.postMessage('ready');},
onStateChange:recipePlayerState,
onAutoplayBlocked:function(){PlayerStatus.postMessage('blocked');},
onError:function(e){PlayerStatus.postMessage('error:'+e.data);}}});}
document.addEventListener('visibilitychange',function(){if(document.hidden)pauseVideo();});
</script><script src="https://www.youtube.com/iframe_api"></script></body></html>''';
}
