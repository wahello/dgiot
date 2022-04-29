%%--------------------------------------------------------------------
%% Copyright (c) 2020-2021 DGIOT Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

-module(dgiot_profile_channel).
-behavior(dgiot_channelx).
-author("jonhliu").
-include("dgiot_task.hrl").
-include_lib("dgiot_bridge/include/dgiot_bridge.hrl").
-include_lib("dgiot/include/logger.hrl").
-define(TYPE, <<"PROFILE">>).
-record(state, {id, mod, product, env = #{}}).

-dgiot_data("ets").
-export([init_ets/0]).
%% API
-export([start/2]).

%% Channel callback
-export([init/3, handle_init/1, handle_event/3, handle_message/2, stop/3]).

%% 注册通道类型

-channel_type(#{

    cType => ?TYPE,
    type => ?BACKEND_CHL,
    title => #{
        zh => <<"配置同步通道"/utf8>>
    },
    description => #{
        zh => <<"设备配置同步通道"/utf8>>
    }
}).
%% 注册通道参数
-params(#{
    <<"vcaddr">> => #{
        order => 1,
        type => string,
        required => false,
        default => <<"all"/utf8>>,
        title => #{
            zh => <<"网关逻辑地址"/utf8>>
        },
        description => #{
            zh => <<"网关逻辑地址"/utf8>>
        }
    },
    <<"mode">> => #{
        order => 2,
        type => enum,
        required => false,
        default => <<"incremental"/utf8>>,
        enum => [<<"incremental">>, <<"fullamount">>],
        title => #{
            zh => <<"下发模式"/utf8>>
        },
        description => #{
            zh => <<"下发模式:incremental|fullamount"/utf8>>
        }
    },
    <<"ico">> => #{
        order => 102,
        type => string,
        required => false,
        default => <<"/dgiot_file/shuwa_tech/zh/product/dgiot/channel/TaskIcon.png">>,
        title => #{
            en => <<"channel ICO">>,
            zh => <<"通道ICO"/utf8>>
        },
        description => #{
            en => <<"channel ICO">>,
            zh => <<"通道ICO"/utf8>>
        }
    }
}).

init_ets() ->
    dgiot_data:init(?PROFILE),
    dgiot_data:init(?MODIFYPROFILE).

start(ChannelId, ChannelArgs) ->
    dgiot_channelx:add(?TYPE, ChannelId, ?MODULE, ChannelArgs).

%% 通道初始化
init(?TYPE, ChannelId, Args) ->
    #{<<"product">> := Products} = Args,
    NewArgs = maps:without([<<"product">>], Args),
    State = #state{id = ChannelId, env = #{
        <<"products">> => Products,
        <<"args">> => NewArgs}
    },
%%    dgiot_parse_hook:subscribe(<<"Device/*">>, put, ChannelId),
    {ok, State, []}.

handle_init(#state{id = _ChannelId, env = #{<<"products">> := _Products, <<"args">> := _Args}} = State) ->
    erlang:send_after(1000, self(), {message, <<"_Pool">>, check_profile}),
    {ok, State}.

%% 通道消息处理,注意：进程池调用
handle_event(_EventId, _Event, State) ->
    {ok, State}.

handle_message({check_profile, _Args}, State) ->
%%%%    ?LOG(info, "Args ~p", [Args]),
%%    Fun = fun(X) ->
%%        ?LOG(info, "X ~p", [X])
%%          end,
%%    dgiot_data:loop(?MODIFYPROFILE, Fun),
    erlang:send_after(1000 * 30, self(), {message, <<"_Pool">>, check_profile}),
    {ok, State};

%%{sync_parse,
%%<<\"{\\\"profile\\\":{\\\"AgreementRelease\\\":\\\"0\\\",\\\"FOTA\\\":\\\"0\\\",\\\"ParaGet\\\":\\\"0\\\",\\\"PowerOffDelay\\\":50,\\\"PowerOnCtrl\\\":0,\\\"PubCtrl\\\":0,\\\"PubFreq\\\":31},\\\"sessiontoken\\\":\\\"r:1b1219229a72e05b79991c01d852d242\\\"}\">>,
%%<<\"248e9007bf\">>
%% }
%%#state{env = #{<<"args">> := #{<<"mode">> := <<"incremental">>}}} =
handle_message({sync_parse, put, _Table, _BeforeData, AfterData, DeviceId}, #state{env = #{<<"args">> := #{<<"mode">> := <<"incremental">>}}} = State) ->
    dgiot_task_hook:put('after',AfterData, DeviceId, <<"incremental">>),
    {ok, State};

handle_message({sync_parse, put, _Table, _Data, AfterData, DeviceId}, State) ->
    dgiot_task_hook:put('after', AfterData, DeviceId,  <<"">>),
    {ok, State};

handle_message(_Message, State) ->
%%    ?LOG(info, "_Message ~p", [_Message]),
    {ok, State}.

stop(ChannelType, ChannelId, #state{env = #{<<"product">> := ProductId, <<"args">> := Args}} = _State) ->
    spawn(fun() ->
        dgiot_task:stop(Args#{<<"product">> => ProductId, <<"channel">> => ChannelId})
          end),
    ?LOG(warning, "channel stop ~p,~p", [ChannelType, ChannelId]),
    ok.

