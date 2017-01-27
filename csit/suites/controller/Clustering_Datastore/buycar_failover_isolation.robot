*** Settings ***
Documentation     This test focuses on testing buy-car RPC over the Leader isolation.
...
...               Copyright (c) 2017 Cisco Systems, Inc. and others. All rights reserved.
...
...               This program and the accompanying materials are made available under the
...               terms of the Eclipse Public License v1.0 which accompanies this distribution,
...               and is available at http://www.eclipse.org/legal/epl-v10.html
...
...
...               All purchases are against the same node, which is the first one to get isolated.
...
...               All data is deleted at the end of the suite.
...               This suite expects car, people and car-people modules to have separate Shards.
Suite Setup       Setup
Test Setup        SetupUtils.Setup_Test_With_Logging_And_Without_Fast_Failing
Default Tags      clustering    carpeople    critical
Library           Collections
Resource          ${CURDIR}/../../../libraries/CarPeople.robot
Resource          ${CURDIR}/../../../libraries/ClusterManagement.robot
Resource          ${CURDIR}/../../../libraries/SetupUtils.robot
Resource          ${CURDIR}/../../../libraries/TemplatedRequests.robot
Variables         ${CURDIR}/../../../variables/Variables.py

*** Variables ***
${CARPEOPLE_ITEMS}    ${100}
${MEMBER_START_TIMEOUT}    300s
@{SHARD_NAME_LIST}    car    people    car-people
${VAR_DIR}        ${CURDIR}/../../../variables/carpeople/crud

*** Test Cases ***
Add_Cars_To_Leader_And_Verify
    [Documentation]    Add all needed cars to car Leader, verify on each member.
    ${car_items} =    BuiltIn.Evaluate    ${CARPEOPLE_ITEMS} * 4
    TemplatedRequests.Put_As_Json_Templated    folder=${VAR_DIR}/cars    session=${car_leader_session}    iterations=${car_items}
    : FOR    ${session}    IN    @{ClusterManagement__session_list}
    \    TemplatedRequests.Get_As_Json_Templated    folder=${VAR_DIR}/cars    session=${session}    verify=True    iterations=${car_items}

Add_People_To_First_Follower_And_Verify
    [Documentation]    Add all needed people to people first Follower, verify on each member.
    ${people_items} =    BuiltIn.Evaluate    ${CARPEOPLE_ITEMS} * 4
    CarPeople.Add_Several_People    session=${people_first_follower_session}    iterations=${people_items}
    : FOR    ${session}    IN    @{ClusterManagement__session_list}
    \    TemplatedRequests.Get_As_Json_Templated    folder=${VAR_DIR}/people    session=${session}    verify=True    iterations=${people_items}

Buy_Cars_On_Leader_And_Verify
    [Documentation]    Buy some cars on the leader member.
    ${iter_start} =    BuiltIn.Evaluate    0 * ${CARPEOPLE_ITEMS} + 1
    CarPeople.Buy_Several_Cars    session=${car-people_leader_session}    iterations=${CARPEOPLE_ITEMS}    iter_start=${iter_start}
    ${total_iterations} =    BuiltIn.Evaluate    1 * ${CARPEOPLE_ITEMS}
    : FOR    ${session}    IN    @{ClusterManagement__session_list}
    \    TemplatedRequests.Get_As_Json_Templated    folder=${VAR_DIR}/car-people    session=${session}    verify=True    iterations=${total_iterations}

Buy_Cars_On_Follower_And_Verify
    [Documentation]    Buy some cars on the first follower member.
    ${iter_start} =    BuiltIn.Evaluate    1 * ${CARPEOPLE_ITEMS} + 1
    CarPeople.Buy_Several_Cars    session=${car-people_first_follower_session}    iterations=${CARPEOPLE_ITEMS}    iter_start=${iter_start}
    ${total_iterations} =    BuiltIn.Evaluate    2 * ${CARPEOPLE_ITEMS}
    : FOR    ${session}    IN    @{ClusterManagement__session_list}
    \    TemplatedRequests.Get_As_Json_Templated    folder=${VAR_DIR}/car-people    session=${session}    verify=True    iterations=${total_iterations}

Isolate_and_Rejoin_People_Leader
    [Documentation]    Previous people Leader is isolated. We should never stop the people first follower, this is where people are registered.
    ClusterManagement.Isolate_Member_From_List_Or_All    ${people_leader_index}
    BuiltIn.Wait_Until_Keyword_Succeeds    10x    2s    ClusterManagement.Verify_Shard_Leader_Elected    people    config    ${True}
    ...    ${people_leader_index}    ${people_follower_indices}
    ClusterManagement.Rejoin_Member_From_List_Or_All    ${people_leader_index}
    BuiltIn.Wait_Until_Keyword_Succeeds    30s    2s    ClusterManagement.Verify_Leader_Exists_For_Each_Shard    shard_name_list=${SHARD_NAME_LIST}    shard_type=config

Buy_Cars_On_Leader_After_Rejoin_And_Verify
    [Documentation]    Buy some cars on the leader member.
    ${iter_start} =    BuiltIn.Evaluate    2 * ${CARPEOPLE_ITEMS} + 1
    CarPeople.Buy_Several_Cars    session=${car-people_leader_session}    iterations=${CARPEOPLE_ITEMS}    iter_start=${iter_start}
    ${total_iterations} =    BuiltIn.Evaluate    3 * ${CARPEOPLE_ITEMS}
    : FOR    ${session}    IN    @{ClusterManagement__session_list}
    \    TemplatedRequests.Get_As_Json_Templated    folder=${VAR_DIR}/car-people    session=${session}    verify=True    iterations=${total_iterations}

Buy_Cars_On_Follower_After_Rejoin_And_Verify
    [Documentation]    Buy some cars on the first follower member.
    ${iter_start} =    BuiltIn.Evaluate    3 * ${CARPEOPLE_ITEMS} + 1
    CarPeople.Buy_Several_Cars    session=${car-people_first_follower_session}    iterations=${CARPEOPLE_ITEMS}    iter_start=${iter_start}
    ${total_iterations} =    BuiltIn.Evaluate    4 * ${CARPEOPLE_ITEMS}
    : FOR    ${session}    IN    @{ClusterManagement__session_list}
    \    TemplatedRequests.Get_As_Json_Templated    folder=${VAR_DIR}/car-people    session=${session}    verify=True    iterations=${total_iterations}

Delete_All_CarPeople
    [Documentation]    DELETE car-people container. No verification beyond http status.
    TemplatedRequests.Delete_Templated    folder=${VAR_DIR}/car-people    session=${car-people_leader_session}

Delete_All_People
    [Documentation]    DELETE people container. No verification beyond http status.
    TemplatedRequests.Delete_Templated    folder=${VAR_DIR}/people    session=${people_leader_session}

Delete_All_Cars
    [Documentation]    DELETE cars container. No verification beyond http status.
    TemplatedRequests.Delete_Templated    folder=${VAR_DIR}/cars    session=${car_leader_session}

*** Keywords ***
Setup
    [Documentation]    Initialize resources, memorize shard leaders, compute item distribution.
    SetupUtils.Setup_Utils_For_Setup_And_Teardown
    Set_Variables_For_Shard    shard_name=car
    Set_Variables_For_Shard    shard_name=people
    Set_Variables_For_Shard    shard_name=car-people
    ${leader_list} =    BuiltIn.Create_List    ${car-people_leader_index}
