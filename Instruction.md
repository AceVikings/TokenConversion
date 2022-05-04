1. Get all Voyage IDs staked by the user with index <br>
```mapping(address=>uint[]) public userStaked```<br>
2. Latest voyage ID of the user by address<br>
```mapping(address=>uint) public voyageId```<br>
3. Voyage Info for user address and Voyage ID<br>
```mapping(address=>mapping(uint=>tokenInfo)) public stakeInfo``` <br>
4. List of all active Voyage IDs by user address <br>
```function getUserStaked(address _user) external view returns(uint[] memory)```
<h2>Instructions</h2>
 1. Retrieve all User Puffs <br>
 2. Retrieve all active voyage IDs as a list using (4) <br>
 3. Make a multicall on that list to retrieve voyage info using (3) <br>
 4. Voyage Info.tokens would contain list of token IDs on voyage for each voyage ID <br>
 5. Voyages run for Info.amount * 1 days, you can retrieve timeStaked from info and calculate end time with that <br>
 
