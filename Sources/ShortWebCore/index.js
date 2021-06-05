var meta = document.createElement('meta');
meta.name = 'viewport';
meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
var head = document.getElementsByTagName('head')[0];
head.appendChild(meta);

function click(element) {
    var ev = new MouseEvent('click', {
        'view': window,
        'bubbles': true,
        'cancelable': true
    });

    element.dispatchEvent(ev);
}

function isInput(element) {
    let nodeName = element.tagName.toLowerCase();

    if (element.nodeType == 1 && (nodeName == "textarea" || (nodeName == "input" && /^(?:text|email|number|search|tel|url|password)$/i.test(element.type))) || element.contentEditable == "true") {

        return true;
    } else {
        return false;
    }
}

function isFileInput(element) {
    return (element.tagName.toLowerCase() == "input" && element.type == "file");
}

function input(element, text) {
    let decoded = decodeURIComponent(escape(window.atob(text)));
    let event = new InputEvent('input', {bubbles: true});
    element.textContent = decoded;
    element.value = decoded;
    setTimeout(function() {
        element.dispatchEvent(event);
    }, (1 * 1000));
}

var getDataUrl = function (img) {
  var canvas = document.createElement('canvas');
  var ctx = canvas.getContext('2d');

  canvas.width = img.width;
  canvas.height = img.height;
  ctx.drawImage(img, 0, 0);

  // If the image is not png, the format
  // must be specified here
  return canvas.toDataURL();
}

function getDomPath(el) {
  if (!el) {
    return;
  }
  var stack = [];
  var isShadow = false;
  while (el.parentNode != null) {
    // console.log(el.nodeName);
    var sibCount = 0;
    var sibIndex = 0;
    // get sibling indexes
    for ( var i = 0; i < el.parentNode.childNodes.length; i++ ) {
      var sib = el.parentNode.childNodes[i];
      if ( sib.nodeName == el.nodeName ) {
        if ( sib === el ) {
          sibIndex = sibCount;
        }
        sibCount++;
      }
    }
    // if ( el.hasAttribute('id') && el.id != '' ) { no id shortcuts, ids are not unique in shadowDom
    //   stack.unshift(el.nodeName.toLowerCase() + '#' + el.id);
    // } else
    var nodeName = el.nodeName.toLowerCase();
    if (isShadow) {
      nodeName += "::shadow";
      isShadow = false;
    }
    if ( sibCount > 1 ) {
      stack.unshift(nodeName + ':nth-of-type(' + (sibIndex + 1) + ')');
    } else {
      stack.unshift(nodeName);
    }
    el = el.parentNode;
    if (el.nodeType === 11) { // for shadow dom, we
      isShadow = true;
      el = el.host;
    }
  }
  stack.splice(0,1); // removes the html element
  return stack.join(' > ');
}

function getData(element) {
    console.log("This is the src:");
    console.log(element.src);
    if (element.src != undefined && element.src != "") {
        console.log("Will return src");
        console.log(element.src)
        return element.src;
    } else {
        return element.innerText;
    }
}

function isSrcUndefined(element) {
    return (element.src == undefined || element.src == "")
}

function getOffset(el) {
  const rect = el.getBoundingClientRect();
  return {
    left: rect.left + window.scrollX,
    top: rect.top + window.scrollY
  };
}

function getOffsetAsArray(el) {
    return [getOffset(el).left, getOffset(el).top]
}

var observeDOM = (function(){
  var MutationObserver = window.MutationObserver || window.WebKitMutationObserver;

  return function( obj, callback ){
    if( !obj || obj.nodeType !== 1 ) return;

    if( MutationObserver ){
      // define a new observer
      var mutationObserver = new MutationObserver(callback)

      // have the observer observe foo for changes in children
      mutationObserver.observe( obj, { childList:true, subtree:true })
      return mutationObserver
    }
    
    // browser support fallback
    else if( window.addEventListener ){
      obj.addEventListener('DOMNodeInserted', callback, false)
      obj.addEventListener('DOMNodeRemoved', callback, false)
      obj.addEventListener('DOMAttrModified', callback, false)
        
    }
  }
})()
    
observeDOM(document.getElementsByTagName("html")[0], function(m){
    var addedNodes = [], removedNodes = [];

    m.forEach(record => record.addedNodes.length & addedNodes.push(...record.addedNodes))
   
    m.forEach(record => record.removedNodes.length & removedNodes.push(...record.removedNodes))

    if (window.webkit != undefined) {
        window.webkit.messageHandlers.ShortWeb.postMessage("DOM Change");
        
        var iframes = [];
        document.querySelectorAll("iframe").forEach(function (item) {
            iframes.push(item.src);
        })
        window.webkit.messageHandlers.ShortWeb.postMessage(iframes);
    }
});

