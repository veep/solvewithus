var server; 
var ws;
var svg;
var mylastchange = 0;
var highlight_id = '';

$(window).load(
    function() {
        server = $('#connection').text();
        ws = new WebSocket(server);
        svg = d3.select("#svgoverlay");

        setup_svg();
        setup_websocket();

        var state;
    // Parse incoming response and post it to the screen
        ws.onmessage = function (msg) {
            var results = JSON.parse(msg.data);
            reset = results.reset;
            state = results.values;
            if (state && state.length) {
                $('#no-data').hide();
            } else {
                $('#no-data').show();
                state = Array();
            }
            change = results.change_number;
            if (reset) {
                ws.close();
                return;
            }
            if (state && state.length && !change || change == mylastchange) {
                redisplay(state);
            }
        };
        
    $('svg').on('click', 'g', function(event) {
        var g = d3.select(this);
        var datum = g.datum();

//        console.log(datum);
        var from;
        var to;
        mylastchange++;

        if (datum.state == 'clear') {
            from = 'clear';
            to = 'fill';
            datum.state = 'fill';
        } else {
            if (datum.state == 'fill') {
                from = 'fill';
                to = 'dot';
                datum.state = 'dot';
            } else {
                if (datum.state == 'dot') {
                    from = 'dot';
                    to = 'clear';
                    datum.state = 'clear';
                }
            }
        }
        g.datum(datum);
        highlight_id = datum.id;
//        console.log(highlight_id);
        redisplay(state);
        update_highlight();
        ws.send(
            JSON.stringify({
                id: datum.id,
                from: from,
                to: to,
                change_number: mylastchange
            })
        );
    });


    $('body').on('keydown', function(event) {
        var value = event.which;
        console.log('keydown',value);

        if (value == 32 || value == 46 || value == 8) {
            var g = svg.selectAll("g .highlightrect");
            var datum = g.datum();
            var from = datum.state;
            if (from == 'clear' && value == 32) {
                to = 'fill';
            } else if (datum.state == 'fill' && value == 32) {
                to = 'dot';
            } else {
                to = 'clear';
            }
            datum.state = to;
            g.datum(datum);
            mylastchange++;
            ws.send(
                JSON.stringify({
                    id: datum.id,
                    from: from,
                    to: to,
                    change_number: mylastchange
                })
            );
            if (value == 8) {
                value = 37;
            } else {
                return false;
            }
        }

        var dir;
        if (value == 38) {
            dir = 'up';
        } else if (value == 37) {
            dir = 'left';
        } else if (value == 40) {
            dir = 'down';
        } else if (value == 39) {
            dir = 'right';
        } else {
            return;
        }
        var g =  svg.selectAll("g").filter( function(d,i) {
            if (d.id === highlight_id) {
                return this;
            }
            return null;
        });
        var datum = g.datum();
        var new_highlight;
        if (dir == 'up' && datum.up) {
            new_highlight = datum.up;
        } else if (dir == 'down' && datum.down) {
            new_highlight = datum.down;
        } else if (dir == 'left' && datum.left) {
            new_highlight = datum.left;
        } else if (dir == 'right' && datum.right) {
            new_highlight = datum.right;
        } else {
            return false;
        }
        highlight_id=new_highlight;
        update_highlight();
        return false;
    });
    
    $('body').on('keypress', function(event) {
        var value = event.which;
        console.log(value);
        if (value >= (96+1) && value <= (96+26)) {
            value=value-32;
        }
        var period = ".".charCodeAt();
            
        if ( (value >= (64+1) && value <= (64+26) )
            || (value >= 48 && value <= 57)
             || value == period
           ) {
            var g = svg.selectAll("g .highlightrect");
            var datum = g.datum();
            var from = datum.state;
            var to = 'text: ' + String.fromCharCode(Number(value));
            if (value == period) {
                if (datum.state == 'dot') {
                    to = 'clear';
                } else {
                    to = 'dot';
                }
            }
            datum.state = to;
            g.datum(datum);
            mylastchange++;
            ws.send(
                JSON.stringify({
                    id: datum.id,
                    from: from,
                    to: to,
                    change_number: mylastchange
                })
            );
        }
    });

        $('#reset_button').click(function () {
            mylastchange++;
            ws.send(
                JSON.stringify ({
                    cmd: "reset",
                    change_number: mylastchange
                })
            );
        });
    }
)

function setup_svg() {
    $('#svgoverlay').height($('#puzzle-image-container').height());
    $('#svgoverlay').width($('#puzzle-image-container').width());
}

function setup_websocket() {
    var lblStatus = $('#status');
    var keepalive_timer_id;
    ws.onopen = function () {
        lblStatus.text('');
        keepalive_timer_id = setInterval(
            function() {
                console.log('Connection keepalive');
                ws.send('{"cmd":"keepalive"}');
            },
            5*1000
        );
    };
    ws.onclose = function() {
        lblStatus.text('Disconnected');
        clearInterval(keepalive_timer_id);
        window.location.reload(true);
    };
    ws.onerror = function(e) {
        lblStatus.text('Error: ' + e.data);
    };

}

var fill_opacity = function(d,type) {
    if ( d.state==='clear' || d.state.substr(0,6) == 'text: ') {
        return 0;
    }
    if ( d.state==='dot' && type=='dot') {
        return 0.5;
    } 
    if ( d.state==='dot' && type=='region') {
        return 0.0;
    } 
    if ( d.state==='fill' && type=='dot') {
        return 0.0;
    } 
    return 0.6;
};

var fill_color = function(d, type) {
    if ( type==='dot') {
        return "green";
    } 
    return "black";
};

function redisplay(state) {
    var g =  svg.selectAll("g").data(state);
    var newg = g.enter().append("g").attr('data-foo',function (d) { return d.id});

    if (! highlight_id) {
        highlight_id = newg.datum().id;
        update_highlight();
    }

    newg
        .append("svg:rect")
        .attr('class','regionrect')
        .attr('x', function(d) { return d.minx})
        .attr('y', function(d) { return d.miny})
        .attr('width', function(d) { return d.maxx - d.minx + 1 })
        .attr('height', function(d) { return d.maxy - d.miny + 1 })
        .attr('fill-opacity', function(d) {return fill_opacity(d,'region')})
        .attr("fill", function(d) {return fill_color(d,'region')});
    newg
        .append("svg:rect")
        .attr('class','clearrect')
        .attr('x', function(d) { 
            return Math.max(
                d.minx,
                Number(d.minx) + (d.maxx - d.minx + 1)/2 - 3
            ) } )
        .attr('y', function(d) { 
            return Math.max(
                d.miny,
                Number(d.miny) + (d.maxy - d.miny + 1)/2 - 3
            ) } )
        .attr('width', function(d) { 
            return Math.min(
                6,
                d.maxx - d.minx + 1
            ) } )
        .attr('height', function(d) { 
            return Math.min(
                6,
                d.maxy - d.miny + 1
            ) } )
        .attr('fill-opacity', function(d) {return fill_opacity(d,'dot') })
        .attr("fill", function(d) {return fill_color(d,'dot') });
    newg
        .append("svg:text")
        .attr('class','regiontext')
        .attr('x', function(d) { return (Number(d.minx)+Number(d.maxx))/2})
        .attr('y', function(d) { return (Number(d.miny)+Number(d.maxy))/2})
        .attr('text-anchor', 'middle')
        .attr('dominant-baseline', 'middle')
        .attr('font-family', 'cursive')
        .attr('font-weight', '400')
        .attr('font-size', function (d) { return (Number(d.maxy)-Number(d.miny))*.9 + "px" })
        .text(function(d) { return d.state.substr(0,6) == 'text: ' ? 
                            d.state.substr(6) : '';
                          });

    g.exit().remove();
    transg = g.transition()
        .duration(120);

    transg
        .select('.regiontext')
        .text(function(d) { return d.state.substr(0,6) == 'text: ' ? 
                            d.state.substr(6) : '';
                          });
    transg
        .select(".regionrect")
        .ease('exp-out')
        .attr('fill-opacity', function(d) {return fill_opacity(d,'region') })
        .attr("fill", function(d) {return fill_color(d,'region')} );
    
    transg
        .select(".clearrect")
        .ease('exp-out')
        .attr('fill-opacity', function(d) {return fill_opacity(d,'dot');})
        .attr("fill",function(d) {return fill_color(d,'dot');});
    

}

function update_highlight() {
    svg.selectAll(".highlightrect").remove();
    var g =  svg.selectAll("g").filter( function(d,i) {
        if (d.id === highlight_id) {
            return this;
        }
        return null;
    });
    //        console.log(g);
    var d = g.datum();
    
    g.append("svg:rect")
        .attr('class','highlightrect')
        .attr('x', Number(d.minx)+1)
        .attr('y', Number(d.miny)+1)
        .attr('width', (d.maxx - d.minx - 2 ))
        .attr('height', (d.maxy - d.miny - 2 ))
        .attr('stroke-width', 3)
        .attr('stroke-opacity', 0.5)
        .attr('stroke', 'red')
        .attr('fill', 'none');
}
