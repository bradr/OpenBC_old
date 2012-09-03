function load_snippet()
{
    var text ="";
    var items = load_snippet.arguments.length;
    for (i=0; i<items; i++) {
        $.get('snippets/'+load_snippet.arguments[i], function(data) { $('#main').append(data); });
//        $('#main').load('snippets/'+load_snippet.arguments[i]);
      //  alert(text);
    }
    return;// text;
}
