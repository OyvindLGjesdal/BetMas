$(document).ready(function(){
        $("select").change(function(){
        $( "select option:selected").each(function(){
        if($(this).attr("value")=="all"){
        $(".list").show();
        }
        if($(this).attr("value")=="mss"){
        $(".list").hide();
        $(".mss").show();
        }
        if($(this).attr("value")=="place"){
        $(".list").hide();
        $(".place").show();
        }
        if($(this).attr("value")=="ins"){
        $(".list").hide();
        $(".ins").show();
        }
        if($(this).attr("value")=="nar"){
        $(".list").hide();
        $(".nar").show();
        }
        if($(this).attr("value")=="pers"){
        $(".list").hide();
        $(".pers").show();
        }
        if($(this).attr("value")=="work"){
        $(".list").hide();
        $(".work").show();
        }
        });
        }).change();
        });