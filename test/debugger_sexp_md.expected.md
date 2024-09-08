
BEGIN DEBUG SESSION 
<details><summary><a id="1"></a> &nbsp; <code>foo = (7 8 16)</code></summary>

- ["test/test_debug_md.ml":7:19](../test/test_debug_md.ml#L7)
- `x = 7`
- <details><summary><a id="2"></a> &nbsp; <code>y = 8</code></summary>
  
  - ["test/test_debug_md.ml":8:6](../test/test_debug_md.ml#L8)
  </details>
  
</details>


<details><summary><a id="3"></a> &nbsp; <code>bar = 336</code></summary>

- ["test/test_debug_md.ml":15:19](../test/test_debug_md.ml#L15)
- `x = ((first 7) (second 42))`
- <details><summary><a id="4"></a> &nbsp; <code>y = 8</code></summary>
  
  - ["test/test_debug_md.ml":16:6](../test/test_debug_md.ml#L16)
  </details>
  
</details>


<details><summary><a id="5"></a> &nbsp; <code>baz = 359</code></summary>

- ["test/test_debug_md.ml":21:19](../test/test_debug_md.ml#L21)
- `x = ((first 7) (second 42))`
- <details><summary><a id="6"></a> &nbsp; <code>_yz = (8 3)</code></summary>
  
  - ["test/test_debug_md.ml":22:17](../test/test_debug_md.ml#L22)
  </details>
  
- <details><summary><a id="7"></a> &nbsp; <code>_uw = (7 13)</code></summary>
  
  - ["test/test_debug_md.ml":23:17](../test/test_debug_md.ml#L23)
  </details>
  
</details>


<details><summary><a id="8"></a> &nbsp; <code>lab = (7 8 16)</code></summary>

- ["test/test_debug_md.ml":28:19](../test/test_debug_md.ml#L28)
- `x = 7`
- <details><summary><a id="9"></a> &nbsp; <code>y = 8</code></summary>
  
  - ["test/test_debug_md.ml":29:6](../test/test_debug_md.ml#L29)
  </details>
  
</details>


<details><summary><a id="10"></a> &nbsp; <code>loop = 36</code></summary>

- ["test/test_debug_md.ml":34:24](../test/test_debug_md.ml#L34)
- `depth = 0`
- `x = ((first 7) (second 42))`
- <details><summary><a id="11"></a> &nbsp; <code>y = 24</code></summary>
  
  - ["test/test_debug_md.ml":38:8](../test/test_debug_md.ml#L38)
  - <details><summary><a id="12"></a> &nbsp; <code>loop = 24</code></summary>
    
    - ["test/test_debug_md.ml":34:24](../test/test_debug_md.ml#L34)
    - `depth = 1`
    - `x = ((first 41) (second 9))`
    - <details><summary><a id="13"></a> &nbsp; <code>y = 25</code></summary>
      
      - ["test/test_debug_md.ml":38:8](../test/test_debug_md.ml#L38)
      - <details><summary><a id="14"></a> &nbsp; <code>loop = 25</code></summary>
        
        - ["test/test_debug_md.ml":34:24](../test/test_debug_md.ml#L34)
        - `depth = 2`
        - `x = ((first 8) (second 43))`
        - <details><summary><a id="15"></a> &nbsp; <code>loop = 25</code></summary>
          
          - ["test/test_debug_md.ml":34:24](../test/test_debug_md.ml#L34)
          - `depth = 3`
          - `x = ((first 44) (second 4))`
          - <details><summary><a id="16"></a> &nbsp; <code>loop = 25</code></summary>
            
            - ["test/test_debug_md.ml":34:24](../test/test_debug_md.ml#L34)
            - `depth = 4`
            - `x = ((first 5) (second 22))`
            - <details><summary><a id="17"></a> &nbsp; <code>loop = 25</code></summary>
              
              - ["test/test_debug_md.ml":34:24](../test/test_debug_md.ml#L34)
              - `depth = 5`
              - `x = ((first 23) (second 2))`
              </details>
              
            </details>
            
          </details>
          
        </details>
        
      </details>
      
    - <details><summary><a id="18"></a> &nbsp; <code>z = 17</code></summary>
      
      - ["test/test_debug_md.ml":39:8](../test/test_debug_md.ml#L39)
      - <details><summary><a id="19"></a> &nbsp; <code>loop = 17</code></summary>
        
        - ["test/test_debug_md.ml":34:24](../test/test_debug_md.ml#L34)
        - `depth = 2`
        - `x = ((first 10) (second 25))`
        - <details><summary><a id="20"></a> &nbsp; <code>loop = 17</code></summary>
          
          - ["test/test_debug_md.ml":34:24](../test/test_debug_md.ml#L34)
          - `depth = 3`
          - `x = ((first 26) (second 5))`
          - <details><summary><a id="21"></a> &nbsp; <code>loop = 17</code></summary>
            
            - ["test/test_debug_md.ml":34:24](../test/test_debug_md.ml#L34)
            - `depth = 4`
            - `x = ((first 6) (second 13))`
            - <details><summary><a id="22"></a> &nbsp; <code>loop = 17</code></summary>
              
              - ["test/test_debug_md.ml":34:24](../test/test_debug_md.ml#L34)
              - `depth = 5`
              - `x = ((first 14) (second 3))`
              </details>
              
            </details>
            
          </details>
          
        </details>
        
      </details>
      
    </details>
    
  </details>
  
- <details><summary><a id="23"></a> &nbsp; <code>z = 29</code></summary>
  
  - ["test/test_debug_md.ml":39:8](../test/test_debug_md.ml#L39)
  - <details><summary><a id="24"></a> &nbsp; <code>loop = 29</code></summary>
    
    - ["test/test_debug_md.ml":34:24](../test/test_debug_md.ml#L34)
    - `depth = 1`
    - `x = ((first 43) (second 24))`
    - <details><summary><a id="25"></a> &nbsp; <code>y = 30</code></summary>
      
      - ["test/test_debug_md.ml":38:8](../test/test_debug_md.ml#L38)
      - <details><summary><a id="26"></a> &nbsp; <code>loop = 30</code></summary>
        
        - ["test/test_debug_md.ml":34:24](../test/test_debug_md.ml#L34)
        - `depth = 2`
        - `x = ((first 23) (second 45))`
        - <details><summary><a id="27"></a> &nbsp; <code>loop = 30</code></summary>
          
          - ["test/test_debug_md.ml":34:24](../test/test_debug_md.ml#L34)
          - `depth = 3`
          - `x = ((first 46) (second 11))`
          - <details><summary><a id="28"></a> &nbsp; <code>loop = 30</code></summary>
            
            - ["test/test_debug_md.ml":34:24](../test/test_debug_md.ml#L34)
            - `depth = 4`
            - `x = ((first 12) (second 23))`
            - <details><summary><a id="29"></a> &nbsp; <code>loop = 30</code></summary>
              
              - ["test/test_debug_md.ml":34:24](../test/test_debug_md.ml#L34)
              - `depth = 5`
              - `x = ((first 24) (second 6))`
              </details>
              
            </details>
            
          </details>
          
        </details>
        
      </details>
      
    - <details><summary><a id="30"></a> &nbsp; <code>z = 22</code></summary>
      
      - ["test/test_debug_md.ml":39:8](../test/test_debug_md.ml#L39)
      - <details><summary><a id="31"></a> &nbsp; <code>loop = 22</code></summary>
        
        - ["test/test_debug_md.ml":34:24](../test/test_debug_md.ml#L34)
        - `depth = 2`
        - `x = ((first 25) (second 30))`
        - <details><summary><a id="32"></a> &nbsp; <code>loop = 22</code></summary>
          
          - ["test/test_debug_md.ml":34:24](../test/test_debug_md.ml#L34)
          - `depth = 3`
          - `x = ((first 31) (second 12))`
          - <details><summary><a id="33"></a> &nbsp; <code>loop = 22</code></summary>
            
            - ["test/test_debug_md.ml":34:24](../test/test_debug_md.ml#L34)
            - `depth = 4`
            - `x = ((first 13) (second 15))`
            - <details><summary><a id="34"></a> &nbsp; <code>loop = 22</code></summary>
              
              - ["test/test_debug_md.ml":34:24](../test/test_debug_md.ml#L34)
              - `depth = 5`
              - `x = ((first 16) (second 6))`
              </details>
              
            </details>
            
          </details>
          
        </details>
        
      </details>
      
    </details>
    
  </details>
  
</details>


