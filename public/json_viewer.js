// ex: set sw=2 et:

// getClass function from http://stackoverflow.com/questions/1249531/how-to-get-a-javascript-objects-class
function getClass(obj) {
  if (typeof obj === 'undefined')
    return 'undefined';
  if (obj === null)
    return 'null';
  return Object.prototype.toString.call(obj)
    .match(/^\[object\s(.*)\]$/)[1];
}

function createElem(className) {
  var elem = document.createElement('div');
  elem.className = className;
  return elem;
}
function textNode(type, text) {
  var elem = createElem(type);
  elem.appendChild(document.createTextNode(text));
  return elem;
}
function blockHeader(text) {
  var node = textNode('block_header', text);
  node.onclick = blockHeader_click;
  return node;
}
function blockHeader_click(event) {
  if (event.target.nextSibling) {
    if (event.target.nextSibling.style.display == 'block') {
      event.target.nextSibling.style.display = 'none';
    } else {
      event.target.nextSibling.style.display = 'block';
    }
  }
}
function itemHeader(text) { return textNode('item_header', text); }
function jsonTree(json) {
  var elem = createElem('container');
  var cls = getClass(json);
  if (cls == 'Array') {
    elem.appendChild(blockHeader('Array'));
    var inner = createElem('inner_container');
    elem.appendChild(inner);
    for (var i=0; i<json.length; i++) {
      inner.appendChild(jsonTree(json[i]));
    }
  } else if (cls == 'Object') {
    elem.appendChild(blockHeader('Hash'));
    var inner = createElem('inner_container');
    elem.appendChild(inner);
    for (var name in json) {
      inner.appendChild(itemHeader(name));
      inner.appendChild(jsonTree(json[name]));
    }
  } else {
    elem.appendChild(document.createTextNode(json));
  }
  return elem;
}
function onload(json) {
  var node = jsonTree(json);
  document.body.appendChild(node);

  // open the top level
  inners = node.getElementsByClassName('inner_container');
  if (inners.length > 0) {
    inners[0].style.display = 'block';
  }
}
