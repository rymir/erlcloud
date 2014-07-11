-module(erlcloud_as).

-include_lib("erlcloud/include/erlcloud_aws.hrl").

-export([describe_groups/0, describe_groups/1, describe_groups/2]).

-import(erlcloud_xml, [get_integer/2, get_text/1, get_text/2]).

-define(API_VERSION, "2011-01-01").

-record(aws_autoscaling_group, {
          group_name::string(),
          availability_zones::list(string()),
          tags::list(string()),
          desired_capacity::integer(),
          min_size::integer(),
          max_size::integer()          
         }).

% xpath for group descriptions used in describe_groups functions:
-define(DESCRIBE_GROUPS_PATH, 
        "/DescribeAutoScalingGroupsResponse/DescribeAutoScalingGroupsResult/AutoScalingGroups/member").

%% --------------------------------------------------------------------
%% @doc Calls describe_groups([], default_configuration())
%% @end
%% --------------------------------------------------------------------
describe_groups() ->
    describe_groups([], erlcloud_aws:default_config()).

%% --------------------------------------------------------------------
%% @doc describe_groups with a specific configuration OR with a 
%% specific list of members.
%% @end
%% --------------------------------------------------------------------
describe_groups(Config) when is_record(Config, aws_config) ->
    describe_groups([], Config);
describe_groups(GroupNames) ->
    describe_groups(GroupNames, erlcloud_aws:default_config()).

%% --------------------------------------------------------------------
%% @doc Get descriptions of the given autoscaling groups.
%%      The account calling this function needs permission for the
%%      autoscaling:DescribeAutoScalingGroups action.
%% @end
%% --------------------------------------------------------------------
-spec describe_groups(list(string()), aws_config()) -> {ok, term()} | {error, term()}.
describe_groups(GN, Config) ->
    MemberKeys = ["AutoScalingGroupNames.member." ++ integer_to_list(I) || I <- lists:seq(1, length(GN))],
    Params = [{K, V} || {K, V} <- lists:zip(MemberKeys, GN)],
    case as_query(Config, "DescribeAutoScalingGroups", Params, ?API_VERSION) of
        {ok, Doc} ->
            Groups = xmerl_xpath:string(?DESCRIBE_GROUPS_PATH, Doc),
            [extract_group(G) || G <- Groups];
        {error, Reason} ->
            {error, Reason}
    end.

extract_group(G) ->
    #aws_autoscaling_group{
       group_name=get_text("AutoScalingGroupName", G),
       tags=extract_tags_from_group(G),
       availability_zones=[get_text(A) || A <- xmerl_xpath:string("AvailabilityZones/member", G)],
       desired_capacity=get_integer("DesiredCapacity", G),
       min_size=get_integer("MinSize", G),
       max_size=get_integer("MaxSize", G)}.
extract_tags_from_group(G) ->
    [{get_text("Key", T), get_text("Value", T)} || T <- xmerl_xpath:string("Tags/member", G)].
       
%% Based on erlcoud_ec2:ec2_query2()
%% TODO:  spec is too general with terms I think:
-spec as_query(aws_config(), string(), list({string(), string()}), string()) -> {ok, term()} | {error, term}.
as_query(Config, Action, Params, ApiVersion) ->
    QParams = [{"Action", Action}, {"Version", ApiVersion}|Params],
    erlcloud_aws:aws_request_xml2(post, Config#aws_config.as_host, 
                                  "/", QParams, Config).