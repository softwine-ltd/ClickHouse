48f17e8a805c167a91a343975ad04c1555ad901d  https://github.com/ClickHouse/ClickHouse/releases/tag/v25.1.5.31-stable Feb 19
004003dccf892ea293c9a7edc71321f46f75669d https://github.com/ClickHouse/ClickHouse/releases/tag/v25.1.6.34-stable Feb 25


kubectl exec -it chi-sonic-sharded-main-0-0-0 --namespace clickhouse-sharded -c clickhouse -- bash
>kubectl -n clickhouse-sharded set image statefulset/chi-sonic-sharded-main-0-0 clickhouse=clickhouse:25.1.8.25
>kubectl -n clickhouse-sharded set image statefulset/chi-sonic-sharded-main-0-0 clickhouse=clickhouse:25.3.2.39
>kubectl -n clickhouse-sharded get pod -w chi-sonic-sharded-main-0-0-0 -o custom-columns="POD NAME:.metadata.name,READY:.status.containerStatuses[*].ready,STATUS:.status.phase,AGE:.metadata.creationTimestamp,IMAGES:.spec.containers[*].image"
>kubectl -n clickhouse-sharded logs -f chi-sonic-sharded-main-0-0-0
>kubectl exec chi-sonic-sharded-main-0-0-0 --namespace clickhouse-sharded -c clickhouse -- clickhouse-client --user=datadog --password hmjejiLDaqJTuIe4 --query "$(cat long_query.sql)" --time
>kubectl exec chi-sonic-sharded-main-0-0-0 --namespace clickhouse-sharded -c clickhouse -- clickhouse-client --user sonic --password 'TLUEH8TdZrxY09tc' --host sonic-cluster-0-0.clickhouse.internal.whaledb.io -q "SELECT arrayStringConcat(arrayReverse(arrayMap(x -> concat(addressToLine(x), '#', demangle(addressToSymbol(x)) ), trace)), ';') AS stack, count() AS samples FROM system.trace_log where query_id = '<query id here>' and trace_type='CPU' GROUP BY trace FORMAT TabSeparated SETTINGS allow_introspection_functions=1"
kubectl exec -it chi-sonic-sharded-main-0-0-0 --namespace clickhouse-sharded -c clickhouse -- clickhouse-client --user sonic --password 'TLUEH8TdZrxY09tc'  -q "SELECT arrayStringConcat(arrayReverse(arrayMap(x -> concat(addressToLine(x), '#', demangle(addressToSymbol(x)) ), trace)), ';') AS stack, count() AS samples FROM system.trace_log where query_id = '5c800464-6e5e-4880-b4fe-0b44fdd5afb4' and trace_type='CPU' GROUP BY trace FORMAT TabSeparated SETTINGS allow_introspection_functions=1" > trace.txt


clickhouse=clickhouse:24.12.6.70 - works well 6.802
                      25.1.5.31- a bit slower 8.106,7.465
                      25.1.7.20  failed to resolve reference 
                      25.1.8.25 - slower (22.903 - anommaly ,)7.517,7.773 base cte: 1.5-2
                                - tests on 20/7/25 shows 8.323, 8.063, 7.908
                      25.3.2.39 - 13.656?
                      25.4.1.2934 - 14.195,14.240
                      25.7.1.3997 -  19.043,   base cte: 3.8,4, 3.9
25.1.8.25<>25.3.2.39
990179ead8b70778910b7ec8c7cdd14d798918a0<>http://github.com/ClickHouse/ClickHouse/commit/3ec1fd3f6908a2eb035fe773c0658aa4d16c0dd4
next steps:
- compare "COPY docker_related_config.xml /etc/clickhouse-server/config.d/ # buildkit" in both images
and "ENV CLICKHOUSE_CONFIG=/etc/clickhouse-server/config.xml" in both
^ they are the same since it's from volume
- try to bin-search how to divide the query
^ The CTE alone took 3.634 on newer version while 1.786 on older version
-use EXPLAIN
compare code changes

5c800464-6e5e-4880-b4fe-0b44fdd5afb4
052e2129-d65e-4652-b339-b996b9a3dfda

times for long_query_org.sql with temp table:
clickhouse:25.1.8.25
0.284
7.042

0.275
6.850

0.252
6.754

0.293
6.681

clickhouse:25.3.2.39
0.277
6.355
0.036


0.306
6.576
0.037


clickhouse:25.7.1.3997
0.321
8.021
0.032

0.296
7.481
0.032