var server; 
var ws;
var svg;
var mylastchange = 0;
var highlight_id = '';
var drag_start;

var Replay = function() {
    this.replay_steps = [];
    this.replay_state = [];
    this.replay_updates_url = '';
}

Replay.prototype.launch = function() {
    console.log('launch');
    var this_replay = this;
    $('body').on('Replay_play_steps', function(event, step) {
//        console.log('in event with',step);
        this_replay.play_steps(step);
    });
    jQuery.getJSON(this.replay_updates_url, function (data) {
        this_replay.replay_steps = data;
        this_replay.data_ready();
    });
}


Replay.prototype.play_steps = function(step) {
    var now = Date.now();
    var max_ts = this.scaler(now);
    console.log(now,max_ts);
    var updated = false;
    while (max_ts 
           && this.replay_steps.length 
           && this.replay_steps[step]
           && (step === 0 || this.replay_steps[step].ts <= max_ts)
          ) {
        if (this.replay_steps[step].type == 'state') {
            this.replay_state = this.replay_steps[step].values;
            redisplay(this.replay_state);
            updated = true;
        }
        if (this.replay_steps[step].type == 'new_state') {
            var new_value = this.replay_steps[step].values;
            this.replay_state.forEach(function(item, index, array) {
                if (item.id == new_value.id) {
                    array[index] = new_value;
                    highlight_id = item.id;
                }
            });
            redisplay(this.replay_state);
            updated = true;
        }
        step++;
    }
    if (updated) {
        update_highlight();
    }
    if (this.replay_steps[step]) {
        window.setTimeout(function() {
            $('body').triggerHandler('Replay_play_steps',step);
        }, 250);
    }
}

            

Replay.prototype.data_ready = function() {
    $('#no-data').hide();
    var start_ts = Date.now();
    this.duration = 30*1000;
    var time_length = (this.replay_steps[this.replay_steps.length-1].ts - this.replay_steps[1].ts)
    this.scaler = function (now) {
        console.log(now,start_ts,this.duration);
        if (now > start_ts+this.duration || this.replay_steps.length < 2) {
            return this.replay_steps[this.replay_steps.length-1].ts;
        }
        return (this.replay_steps[1].ts + 
                time_length
                * (now - start_ts) / this.duration);
    };
    $('body').triggerHandler('Replay_play_steps',0);
    $('#replay-controls').show();
}


$(window).load(
    function() {
        svg = d3.select("#svgoverlay");
        if (Replay.replay_updates_url) {
            console.log(Replay.replay_updates_url);
            Replay.launch();
            return;
        }
        server = $('#connection').text();
        ws = new WebSocket(server);

        setup_svg();
        setup_websocket();

        var state;
    // Parse incoming response and post it to the screen
        ws.onmessage = function (msg) {
            var results = JSON.parse(msg.data);
            change = results.change_number;
            if (!change || change == mylastchange) {
                state = results.values;
                if (state && state.length) {
                    $('#no-data').hide();
                    redisplay(state);
                } else {
                    $('#no-data').show();
                    state = Array();
                }
            }
            reset = results.reset;
            if (reset) {
                ws.close();
                return;
            }
        };

    $('svg').on('mousedown', 'g', function(event) {
        var g = d3.select(this);
        var datum = g.datum();
        drag_start = datum;
    });

    $('svg').on('mouseover', 'g', function(event) {
        if (!drag_start) {
            return;
        }
        drag_start = state.filter(function(item) {
            return item.id === drag_start.id;
        })[0];
        var command;
        var g = d3.select(this);
        var datum = g.datum();
        if (datum.up == drag_start.id) {
            if (datum.state_up == 'on' && drag_start.state_down == 'on') {
                datum.state_up = '';
                drag_start.state_down = '';
                command = 'clear';
            } else {
                datum.state_up = 'on';
                drag_start.state_down = 'on';
                command = 'on';
            }
        }
        if (datum.down == drag_start.id) {
            if (datum.state_down == 'on' && drag_start.state_up == 'on') {
                datum.state_down = '';
                drag_start.state_up = '';
                command = 'clear';
            } else {
                datum.state_down = 'on';
                drag_start.state_up = 'on';
                command = 'on';
            }
        }
        if (datum.left == drag_start.id) {
            if (datum.state_left == 'on' && drag_start.state_right == 'on') {
                datum.state_left = '';
                drag_start.state_right = '';
                command = 'clear';
            } else {
                datum.state_left = 'on';
                drag_start.state_right = 'on';
                command = 'on';
            }
        }
        if (datum.right == drag_start.id) {
            if (datum.state_right == 'on' && drag_start.state_left == 'on') {
                datum.state_right = '';
                drag_start.state_left = '';
                command = 'clear';
            } else {
                datum.state_right = 'on';
                drag_start.state_left = 'on';
                command = 'on';
            }
        }
        if (! command) {
            return;
        }
        if (command == 'on') {
            if (datum.state == 'dot') {
                datum.state = 'clear';
            }
            if (drag_start.state == 'dot') {
                drag_start.state = 'clear';
            }
        }
        redisplay(state);
        highlight_id = datum.id;
        update_highlight();
        mylastchange++;
        ws.send(
            JSON.stringify({
                cmd: "line_" + command,
                start_id: drag_start.id,
                stop_id: datum.id,
                change_number: mylastchange
            })
        );
        drag_start = datum;
    });

    $('body').on('mouseup', function(event) {
        drag_start = false;
    });
        
    $('svg').on('click', 'g', function(event) {
        var g = d3.select(this);
        var datum = g.datum();

//        console.log(datum);
        if ($('#click_fill:checked').val()) {
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
            redisplay(state);
            ws.send(
                JSON.stringify({
                    id: datum.id,
                    from: from,
                    to: to,
                    change_number: mylastchange
                })
            );
        }
        highlight_id = datum.id;
        update_highlight();
    });


    $('body').on('keydown', function(event) {
        var value = event.which;

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
    if ( type === 'line_up') {
        if (d.state_up && d.state_up === 'on') {
            return 0.8;
        } else {
            return 0;
        }
    }
    if ( type === 'line_down') {
        if (d.state_down && d.state_down === 'on') {
            return 0.8;
        } else {
            return 0;
        }
    }
    if ( type === 'line_right') {
        if (d.state_right && d.state_right === 'on') {
            return 0.8;
        } else {
            return 0;
        }
    }
    if ( type === 'line_left') {
        if (d.state_left && d.state_left === 'on') {
            return 0.8;
        } else {
            return 0;
        }
    }
    if (! d.state) {
        return 0;
    }
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

    newg
        .append("svg:rect")
        .attr('class','line_up')
        .attr('x', function(d) { return (Number(d.minx)+Number(d.maxx))/2})
        .attr('y', function(d) { return Number(d.miny) })
        .attr('width', function(d) { return 3 })
        .attr('height', function(d) { return (d.maxy - d.miny)/2+1 })
        .attr('fill-opacity', function(d) {return fill_opacity(d,'line_up')})
        .attr("fill", function(d) {return fill_color(d,'line_up')});
    newg
        .append("svg:rect")
        .attr('class','line_down')
        .attr('x', function(d) { return (Number(d.minx)+Number(d.maxx))/2})
        .attr('y', function(d) { return (Number(d.miny)+Number(d.maxy))/2})
        .attr('width', function(d) { return 3 })
        .attr('height', function(d) { return (d.maxy - d.miny)/2+1 })
        .attr('fill-opacity', function(d) {return fill_opacity(d,'line_down')})
        .attr("fill", function(d) {return fill_color(d,'line_down')});
    newg
        .append("svg:rect")
        .attr('class','line_left')
        .attr('x', function(d) { return (Number(d.minx))})
        .attr('y', function(d) { return (Number(d.miny)+Number(d.maxy))/2})
        .attr('width', function(d) { return (d.maxx - d.minx)/2+3  })
        .attr('height', function(d) { return 3 })
        .attr('fill-opacity', function(d) {return fill_opacity(d,'line_left')})
        .attr("fill", function(d) {return fill_color(d,'line_left')});
    newg
        .append("svg:rect")
        .attr('class','line_right')
        .attr('x', function(d) { return (Number(d.minx)+Number(d.maxx))/2})
        .attr('y', function(d) { return (Number(d.miny)+Number(d.maxy))/2})
        .attr('width', function(d) { return (d.maxx - d.minx)/2+2  })
        .attr('height', function(d) { return 3 })
        .attr('fill-opacity', function(d) {return fill_opacity(d,'line_right')})
        .attr("fill", function(d) {return fill_color(d,'line_right')});
    // newg
    //     .append("svg:rect")
    //     .attr('class','regionrect')
    //     .attr('x', function(d) { return d.minx})
    //     .attr('y', function(d) { return d.miny})
    //     .attr('width', function(d) { return d.maxx - d.minx + 1 })
    //     .attr('height', function(d) { return d.maxy - d.miny + 1 })
    //     .attr('fill-opacity', function(d) {return fill_opacity(d,'region')})
    //     .attr("fill", function(d) {return fill_color(d,'region')});
    // newg
    //     .append("svg:rect")
    //     .attr('class','regionrect')
    //     .attr('x', function(d) { return d.minx})
    //     .attr('y', function(d) { return d.miny})
    //     .attr('width', function(d) { return d.maxx - d.minx + 1 })
    //     .attr('height', function(d) { return d.maxy - d.miny + 1 })
    //     .attr('fill-opacity', function(d) {return fill_opacity(d,'region')})
    //     .attr("fill", function(d) {return fill_color(d,'region')});

    g.exit().remove();
    transg = g.transition()
        .duration(120);

    transg
        .select('.regiontext')
        .text(function(d) { return (d.state && d.state.substr(0,6) == 'text: ') ? 
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
    
    transg
        .select(".line_up")
        .ease('exp-out')
        .attr('fill-opacity', function(d) {return fill_opacity(d,'line_up') })
        .attr("fill", function(d) {return fill_color(d,'line_up')} );

    transg
        .select(".line_down")
        .ease('exp-out')
        .attr('fill-opacity', function(d) {return fill_opacity(d,'line_down') })
        .attr("fill", function(d) {return fill_color(d,'line_down')} );

    transg
        .select(".line_left")
        .ease('exp-out')
        .attr('fill-opacity', function(d) {return fill_opacity(d,'line_left') })
        .attr("fill", function(d) {return fill_color(d,'line_left')} );
    transg
        .select(".line_right")
        .ease('exp-out')
        .attr('fill-opacity', function(d) {return fill_opacity(d,'line_right') })
        .attr("fill", function(d) {return fill_color(d,'line_right')} );
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
