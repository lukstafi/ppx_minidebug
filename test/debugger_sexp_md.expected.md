
BEGIN DEBUG SESSION 
<details><summary><code>foo = (7 8 16)</code></summary>

- ["test/test_debug_md.ml":8:19-10:17](../test/test_debug_md.ml#L8)
- `x = 7`
- <details><summary><code>y = 8</code></summary>
  
  - ["test/test_debug_md.ml":9:6](../test/test_debug_md.ml#L9)
  </details>
  
</details>


<details><summary><code>bar = 336</code></summary>

- ["test/test_debug_md.ml":16:19-18:14](../test/test_debug_md.ml#L16)
- `x = ((first 7) (second 42))`
- <details><summary><code>y = 8</code></summary>
  
  - ["test/test_debug_md.ml":17:6](../test/test_debug_md.ml#L17)
  </details>
  
</details>


<details><summary><code>baz = 359</code></summary>

- ["test/test_debug_md.ml":22:19-25:28](../test/test_debug_md.ml#L22)
- `x = ((first 7) (second 42))`
- <details><summary><code>_yz = (8 3)</code></summary>
  
  - ["test/test_debug_md.ml":23:17](../test/test_debug_md.ml#L23)
  </details>
  
- <details><summary><code>_uw = (7 13)</code></summary>
  
  - ["test/test_debug_md.ml":24:17](../test/test_debug_md.ml#L24)
  </details>
  
</details>


<details><summary><code>lab = (7 8 16)</code></summary>

- ["test/test_debug_md.ml":29:19-31:17](../test/test_debug_md.ml#L29)
- `x = 7`
- <details><summary><code>y = 8</code></summary>
  
  - ["test/test_debug_md.ml":30:6](../test/test_debug_md.ml#L30)
  </details>
  
</details>


<details><summary><code>loop = 36</code></summary>

- ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
- `depth = 0`
- `x = ((first 7) (second 42))`
- <details><summary><code>y = 24</code></summary>
  
  - ["test/test_debug_md.ml":39:8](../test/test_debug_md.ml#L39)
  - <details><summary><code>loop = 24</code></summary>
    
    - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
    - `depth = 1`
    - `x = ((first 41) (second 9))`
    - <details><summary><code>y = 25</code></summary>
      
      - ["test/test_debug_md.ml":39:8](../test/test_debug_md.ml#L39)
      - <details><summary><code>loop = 25</code></summary>
        
        - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
        - `depth = 2`
        - `x = ((first 8) (second 43))`
        - <details><summary><code>loop = 25</code></summary>
          
          - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
          - `depth = 3`
          - `x = ((first 44) (second 4))`
          - <details><summary><code>loop = 25</code></summary>
            
            - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
            - `depth = 4`
            - `x = ((first 5) (second 22))`
            - <details><summary><code>loop = 25</code></summary>
              
              - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
              - `depth = 5`
              - `x = ((first 23) (second 2))`
              </details>
              
            </details>
            
          </details>
          
        </details>
        
      </details>
      
    - <details><summary><code>z = 17</code></summary>
      
      - ["test/test_debug_md.ml":40:8](../test/test_debug_md.ml#L40)
      - <details><summary><code>loop = 17</code></summary>
        
        - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
        - `depth = 2`
        - `x = ((first 10) (second 25))`
        - <details><summary><code>loop = 17</code></summary>
          
          - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
          - `depth = 3`
          - `x = ((first 26) (second 5))`
          - <details><summary><code>loop = 17</code></summary>
            
            - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
            - `depth = 4`
            - `x = ((first 6) (second 13))`
            - <details><summary><code>loop = 17</code></summary>
              
              - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
              - `depth = 5`
              - `x = ((first 14) (second 3))`
              </details>
              
            </details>
            
          </details>
          
        </details>
        
      </details>
      
    </details>
    
  </details>
  
- <details><summary><code>z = 29</code></summary>
  
  - ["test/test_debug_md.ml":40:8](../test/test_debug_md.ml#L40)
  - <details><summary><code>loop = 29</code></summary>
    
    - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
    - `depth = 1`
    - `x = ((first 43) (second 24))`
    - <details><summary><code>y = 30</code></summary>
      
      - ["test/test_debug_md.ml":39:8](../test/test_debug_md.ml#L39)
      - <details><summary><code>loop = 30</code></summary>
        
        - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
        - `depth = 2`
        - `x = ((first 23) (second 45))`
        - <details><summary><code>loop = 30</code></summary>
          
          - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
          - `depth = 3`
          - `x = ((first 46) (second 11))`
          - <details><summary><code>loop = 30</code></summary>
            
            - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
            - `depth = 4`
            - `x = ((first 12) (second 23))`
            - <details><summary><code>loop = 30</code></summary>
              
              - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
              - `depth = 5`
              - `x = ((first 24) (second 6))`
              </details>
              
            </details>
            
          </details>
          
        </details>
        
      </details>
      
    - <details><summary><code>z = 22</code></summary>
      
      - ["test/test_debug_md.ml":40:8](../test/test_debug_md.ml#L40)
      - <details><summary><code>loop = 22</code></summary>
        
        - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
        - `depth = 2`
        - `x = ((first 25) (second 30))`
        - <details><summary><code>loop = 22</code></summary>
          
          - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
          - `depth = 3`
          - `x = ((first 31) (second 12))`
          - <details><summary><code>loop = 22</code></summary>
            
            - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
            - `depth = 4`
            - `x = ((first 13) (second 15))`
            - <details><summary><code>loop = 22</code></summary>
              
              - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
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


