

# Exometer Collectd reporter #

Copyright (c) 2014 Basho Technologies, Inc.  All Rights Reserved.

__Version:__ Nov 6 2018 08:44:40

__Authors:__ Ulf Wiger ([`ulf.wiger@feuerlabs.com`](mailto:ulf.wiger@feuerlabs.com)), Magnus Feuer ([`magnus.feuer@feuerlabs.com`](mailto:magnus.feuer@feuerlabs.com)).

[![Travis][travis badge]][travis]
[![Hex.pm Version][hex version badge]][hex]
[![Hex.pm License][hex license badge]][hex]
[![Erlang Versions][erlang version badge]][travis]
[![Build Tool][build tool]][hex]


#### <a name="exometer_report_collectd">exometer_report_collectd</a> ####

The collectd reporter communicates with a local `collectd` process
through its unix socket protocol. All subscribed-to metric-datapoint
values received by the reporter are immediately forwarded to
`collectd`. Once a value has been forwarded, the reporter continuously
refreshes the value toward `collectd` at a configurable interval in order
to keep it from expiring inside `collectd`.

If the `collectd` connection is lost, the reporter will attempt to reconnect to it
at a configurable interval.

All metrics reported to collectd will be have identifiers formatted as follows:

```
HostName/PluginName-PluginInstance/Type-Metric_DataPoint
```

+ `HostName`<br />Host name of the entry.<br />Configurable through the `hostname` application environment parameter.<br />Default is the value returned by `netadm:localhost()`.

+ `PluginName`<br />The collectd plugin name.<br />Configurable through the `plugin_name` application environment parameter.<br />Default is `exometer`.

+ `PluginInstance`<br />The instance ID to use for the plugin.<br />Configurable through the `plugin_instance` application environment parameter.<br />Default is the erlang node name in the left hand side of the value
    returned by `node()`.

+ `Type`<br />Type assigned to the reported value.<br />The type is looked up through the `type_map`.<br />The given metric and data points are used as a key in a list format,
    such as `[ db, cache, hits, median ]`. The type that is resolved from
    the metric/data point will be used as the `Type` component in the
    collectd identifier. Please see types.db(5) for a list of available
    collectd types.<br />Default for `Type` is 'gauge'.

+ `Metric`<br />The name of the metric. The atoms in the metric list will be converted
    to a string separated by `_`. Thus `[ db, cache, hits ]` will be converted
    to `db_cache_hits`.

+ `DataPoint`<br />The data point of the given metric.
Will be added to the end of the metrics string.

Please see [Configuring collectd reporter](https://github.com/Feuerlabs/exometer_collectd/blob/master/doc/README.md#Configuring_collectd_reporter) for details on the
application environment parameters listed above.


#### <a name="Setting_up_subscriptions">Setting up subscriptions</a> ####

A subscription can either be statically configured, or dynamically
setup from within the code using Exometer. For details on statically
configured subscriptions, please see [Configuring static subscriptions](https://github.com/Feuerlabs/exometer_collectd/blob/master/doc/README.md#Configuring_static_subscriptions).

A dynamic subscription can be setup with the following call:

```erlang

exometer_report:subscribe(Recipient, Metric, DataPoint, Inteval)
```

`Recipient` is the name of a reporter.


#### <a name="Configuring_type_-_entry_maps">Configuring type - entry maps</a> ####

The dynamic method of configuring defaults for `exometer` entries is:

```erlang

exometer_admin:set_default(NamePattern, Type, Default)
```

Where `NamePattern` is a list of terms describing what is essentially
a name prefix with optional wildcards (`'_'`). A pattern that
matches any legal name is `['_']`.

`Type` is an atom defining a type of metric. The types already known to
`exometer`, `counter`, `fast_counter`, `ticker`, `uniform`, `histogram`,
`spiral`, `netlink`, and `probe` may be redefined, but other types can be
described as well.

`Default` is either an `#exometer_entry{}` record (unlikely), or a list of
`{Key, Value}` options, where the keys correspond to `#exometer_entry` record
attribute names. The following attributes make sense to preset:

```erlang

{module, atom()}              % the callback module
{status, enabled | disabled}  % operational status of the entry
{cache, non_neg_integer()}    % cache lifetime (ms)
{options, [{atom(), any()}]}  % entry-specific options
```

Below is an example, from `exometer/priv/app.config`:

```erlang

{exometer, [
    {defaults, [
        {['_'], function , [{module, exometer_function}]},
        {['_'], counter  , [{module, exometer}]},
        {['_'], histogram, [{module, exometer_histogram}]},
        {['_'], spiral   , [{module, exometer_spiral}]},
        {['_'], duration , [{module, exometer_folsom}]},
        {['_'], meter    , [{module, exometer_folsom}]},
        {['_'], gauge    , [{module, exometer_folsom}]}
    ]}
]}
```

In systems that use CuttleFish, the file `exometer/priv/exometer.schema`
contains a schema for default settings. The setup corresponding to the above
defaults would be as follows:

```ini

exometer.template.function.module  = exometer_function
exometer.template.counter.module   = exometer
exometer.template.histogram.module = exometer_histogram
exometer.template.spiral.module    = exometer_spiral
exometer.template.duration.module  = exometer_folsom
exometer.template.meter.module     = exometer_folsom
exometer.template.gauge.module     = exometer_folsom
```


#### <a name="Configuring_static_subscriptions">Configuring static subscriptions</a> ####

Static subscriptions, which are automatically setup at exometer
startup without having to invoke `exometer_report:subscribe()`, are
configured through the report sub section under exometer.

Below is an example, from `exometer/priv/app.config`:

```erlang

{exometer, [
    {report, [
        {subscribers, [
            {exometer_report_collectd, [db, cache, hits], mean, 2000, true},
            {exometer_report_collectd, [db, cache, hits], max, 5000, false}
        ]}
    ]}
]}
```

The `report` section configures static subscriptions and reporter
plugins. See [Configuring reporter plugins](https://github.com/Feuerlabs/exometer_collectd/blob/master/doc/README.md#Configuring_reporter_plugins) for details on
how to configure individual plugins.

The `subscribers` sub-section contains all static subscriptions to be
setup att exometer applications start. Each tuple in the prop list
should be of one of the following formats:

* `{Reporter, Metric, DataPoint, Interval}`

* `{Reporter, Metric, DataPoint, Interval, RetryFailedMetrics}`

* `{Reporter, Metric, DataPoint, Interval, RetryFailedMetrics, Extra}`

* `{apply, {M, F, A}}`

* `{select, {MatchPattern, DataPoint, Interval [, Retry [, Extra] ]}}`

In the case of `{apply, M, F, A}`, the result of `apply(M, F, A)` must
be a list of `subscribers` tuples.

In the case of `{select, Expr}`, a list of metrics is fetched using
`exometer:select(MatchPattern)`, where the result must be on the form
`{Key, Type, Status}` (i.e. what corresponds to `'$_'`).
The rest of the items will be applied to each of the matching entries.

The meaning of the above tuple elements is:

+ `Reporter :: module()`<br />Specifies the reporter plugin module, such as`exometer_report_collectd` that is to receive updated metric's data
points.

+ `Metric :: [atoms()]`<br />Specifies the path to a metric previously created with an`exometer:new()` call.

+ `DataPoint` ::  atom() | [atom()]'<br />Specifies the data point within the given metric to send to the
    receiver. The data point must match one of the data points returned by`exometer:info(Name, datapoints)` for the given metrics name.

+ `Interval` :: integer()' (milliseconds)<br />Specifies the interval, in milliseconds, between each update of the
given metric's data point. At the given interval, the data point will
be samples, and the result will be sent to the receiver.

+ `RetryFailedMetrics :: boolean()`<br />Specifies if the metric should be continued to be reported
    even if it is not found during a reporting cycle. This would be
    the case if a metric is not created by the time it is reported for
    the first time. If the metric will be created at a later time,
    this value should be set to true. Set this value to false if all
    attempts to report the metric should stop if when is not found.
    The default value is `true`.

+ `Extra :: any()`<br />Provides a means to pass along extra information for a given
   subscription. An example is the `syntax` option for the SNMP reporter,
   in which case `Extra` needs to be a property list.

Example configuration in sys.config, using the `{select, Expr}` pattern:

```erlang

[
 {exometer, [
             {predefined,
              [{[a,1], counter, []},
               {[a,2], counter, []},
               {[b,1], counter, []},
               {[c,1], counter, []}]},
             {report,
              [
               {reporters,
                [{exometer_report_tty, []}]},
               {subscribers,
                [{select, {[{ {[a,'_'],'_','_'}, [], ['$_']}],
                           exometer_report_tty, value, 1000}}]}
              ]}
            ]}
].

```

This will activate a subscription on `[a,1]` and `[a,2]` in the
`exometer_report_tty` reporter, firing once per second.


#### <a name="Configuring_collectd_reporter">Configuring collectd reporter</a> ####

Below is an example of the collectd reporter application environment, with
its correct location in the hierarchy:

```erlang

{exometer, [
    {report, [
        {reporters, [
            {exometer_report_collectd, [
                {reconnect_interval, 10},
                {refresh_interval, 20},
                {read_timeout, 5000},
                {connect_timeout, 8000},
                {hostname, "testhost"},
                {path, "/var/run/collectd-unixsock"},
                {plugin_name, "testname"},
                {plugin_instance, "testnode"},
                {type_map,
                    [{[db, cache, hits, max], "gauge"}]
                }
            ]}
        ]}
    ]}
]}
```

The following attributes are available for configuration:

+ `reconnect_interval` (seconds - default: 30)<br />Specifies the duration between each reconnect attempt to a collectd
server that is not available. Should the server either be unavailable
at exometer startup, or become unavailable during exometer's
operation, exometer will attempt to reconnect at the given number of
seconds.

+ `refresh_interval` (seconds - default: 10)<br />Specifies how often a value, which has not been updated by exometer,
is to be resent with its current value to collectd. If collectd does
not see an identifier updated at a given number of seconds (see
Timeout in collectd.conf(5)), it will be removed from the list of
maintained identifiers.

+ `read_timeout` (milliseconds - default: 5000)<br />Specifies how long the collectd reporter plugin shall wait for an
acknowledgement from collectd after sending it an updated value.  If
an acknowledgment is not received within the given interval, the
plugin will disconnect from the collectd server and reconnect to it
after the given reconnect interval (see item one above).

+ `connect_timeout` (milliseconds - default: 5000)<br />Specifies how long the collectd reporter plugin shall wait for a unix
socket connection to complete before timing out. A timed out
connection attempt will be retried after the reconnect interval has
passed see item 1 above).

+ `path` (file path - default: "/var/run/collectd-unixsock")<br />Specifies the path to the named unix socket that collectd is listening
on. When exometer starts and loads the collectd reporter plugin, the
plugin will connect to the given socket.

+ `plugin_name` (string - default: "exometer")<br />Specifies the plugin name to use when constructing an collectd identifier.
    Please see [Configuring collectd reporter](https://github.com/Feuerlabs/exometer_collectd/blob/master/doc/README.md#Configuring_collectd_reporter) for details.

+ `plugin_instance` (string - default: left hand side of `node()`)<br />Specifies the plugin instance id to use when constructing an collectd identifier.
    Please see [Configuring collectd reporter](https://github.com/Feuerlabs/exometer_collectd/blob/master/doc/README.md#Configuring_collectd_reporter) for details.

+ `plugin_instance` (string - default: left hand side of `node()`)<br />Specifies the plugin instance id to use when constructing an collectd identifier.
    Please see [Configuring collectd reporter](https://github.com/Feuerlabs/exometer_collectd/blob/master/doc/README.md#Configuring_collectd_reporter) for details.

+ `hostname` (string - default: `net_adm:localhost()`)<br />Specifies the host name to use when constructing an collectd identifier.
    Please see [Configuring collectd reporter](https://github.com/Feuerlabs/exometer_collectd/blob/master/doc/README.md#Configuring_collectd_reporter) for details.

+ `type_map` (prop list - default: n/a)<br />Specifies the mapping between metrics/datapoints and the collectd type
to use when sending an updated metric value. See below.

Type maps must be provided since there is no natural connection
between the type of a metric/datapoint pair and an identifier in
collectd. The `type_map` consists of a prop list that converts a path
to a metric/datapoint to a string that can be used as a type when
reporting to collectd.

The key part of each element in the list consists of a list of atoms
that matches the name of the metrics, with the name of the data point
added as a final element. If the metric is identified as `[ webserver,
https, get_count ]`, and the data point is called `total`, the key in
the type_map would be `[ webserver, https, get_count, total ]`, The
value part of a property is the type string to use when reporting to
collectd. Please see types.db(5) for a list of available collectd
types.  A complete entry in the `type_map` list would be: `{ [
webserver, https, get_count, total ], "counter" }`.

[travis]: https://travis-ci.org/Feuerlabs/exometer_collectd
[travis badge]: https://img.shields.io/travis/Feuerlabs/exometer_collectd/master.svg?style=flat-square
[hex]: https://hex.pm/packages/exometer_collectd
[hex version badge]: https://img.shields.io/hexpm/v/exometer_collectd.svg?style=flat-square
[hex license badge]: https://img.shields.io/hexpm/l/exometer_collectd.svg?style=flat-square
[erlang version badge]: https://img.shields.io/badge/erlang-18--21-blue.svg?style=flat-square
[build tool]: https://img.shields.io/badge/build%20tool-rebar3-orange.svg?style=flat-square


## Modules ##


<table width="100%" border="0" summary="list of modules">
<tr><td><a href="https://github.com/Feuerlabs/exometer_collectd/blob/master/doc/exometer_report_collectd.md" class="module">exometer_report_collectd</a></td></tr></table>

