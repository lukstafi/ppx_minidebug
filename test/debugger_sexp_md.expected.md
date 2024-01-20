
BEGIN DEBUG SESSION

HTML CONFIG: values_first_mode=true hyperlink=../

<details><summary>`foo = (7 8 16)`</summary>

- ["test/test_debug_md.ml":7:19-9:17](../test/test_debug_md.ml#L7)
- `x = 7`
- <details><summary>`y = 8`</summary>
  
  - ["test/test_debug_md.ml":8:6](../test/test_debug_md.ml#L8)
  </details>
</details>

<details><summary>`bar = 336`</summary>

- ["test/test_debug_md.ml":15:19-17:14](../test/test_debug_md.ml#L15)
- `x = ((first 7) (second 42))`
- <details><summary>`y = 8`</summary>
  
  - ["test/test_debug_md.ml":16:6](../test/test_debug_md.ml#L16)
  </details>
</details>

<details><summary>`baz = 359`</summary>

- ["test/test_debug_md.ml":21:19-24:28](../test/test_debug_md.ml#L21)
- `x = ((first 7) (second 42))`
- <details><summary>`_yz = (8 3)`</summary>
  
  - ["test/test_debug_md.ml":22:17](../test/test_debug_md.ml#L22)
  </details>
- <details><summary>`_uw = (7 13)`</summary>
  
  - ["test/test_debug_md.ml":23:17](../test/test_debug_md.ml#L23)
  </details>
</details>

<details><summary>`lab = (7 8 16)`</summary>

- ["test/test_debug_md.ml":28:19-30:17](../test/test_debug_md.ml#L28)
- `x = 7`
- <details><summary>`y = 8`</summary>
  
  - ["test/test_debug_md.ml":29:6](../test/test_debug_md.ml#L29)
  </details>
</details>

<details><summary>`loop = 36`</summary>

- ["test/test_debug_md.ml":34:24-40:9](../test/test_debug_md.ml#L34)
- `depth = 0`
- `x = ((first 7) (second 42))`
- <details><summary>`y = 24`</summary>
  
  - ["test/test_debug_md.ml":38:8](../test/test_debug_md.ml#L38)
  - <details><summary>`loop = 24`</summary>
    
    - ["test/test_debug_md.ml":34:24-40:9](../test/test_debug_md.ml#L34)
    - `depth = 1`
    - `x = ((first 41) (second 9))`
    - <details><summary>`y = 25`</summary>
      
      - ["test/test_debug_md.ml":38:8](../test/test_debug_md.ml#L38)
      - <details><summary>`loop = 25`</summary>
        
        - ["test/test_debug_md.ml":34:24-40:9](../test/test_debug_md.ml#L34)
        - `depth = 2`
        - `x = ((first 8) (second 43))`
        - <details><summary>`loop = 25`</summary>
          
          - ["test/test_debug_md.ml":34:24-40:9](../test/test_debug_md.ml#L34)
          - `depth = 3`
          - `x = ((first 44) (second 4))`
          - <details><summary>`loop = 25`</summary>
            
            - ["test/test_debug_md.ml":34:24-40:9](../test/test_debug_md.ml#L34)
            - `depth = 4`
            - `x = ((first 5) (second 22))`
            - <details><summary>`loop = 25`</summary>
              
              - ["test/test_debug_md.ml":34:24-40:9](../test/test_debug_md.ml#L34)
              - `depth = 5`
              - `x = ((first 23) (second 2))`
              </details>
            </details>
          </details>
        </details>
      </details>
    - <details><summary>`z = 17`</summary>
      
      - ["test/test_debug_md.ml":39:8](../test/test_debug_md.ml#L39)
      - <details><summary>`loop = 17`</summary>
        
        - ["test/test_debug_md.ml":34:24-40:9](../test/test_debug_md.ml#L34)
        - `depth = 2`
        - `x = ((first 10) (second 25))`
        - <details><summary>`loop = 17`</summary>
          
          - ["test/test_debug_md.ml":34:24-40:9](../test/test_debug_md.ml#L34)
          - `depth = 3`
          - `x = ((first 26) (second 5))`
          - <details><summary>`loop = 17`</summary>
            
            - ["test/test_debug_md.ml":34:24-40:9](../test/test_debug_md.ml#L34)
            - `depth = 4`
            - `x = ((first 6) (second 13))`
            - <details><summary>`loop = 17`</summary>
              
              - ["test/test_debug_md.ml":34:24-40:9](../test/test_debug_md.ml#L34)
              - `depth = 5`
              - `x = ((first 14) (second 3))`
              </details>
            </details>
          </details>
        </details>
      </details>
    </details>
  </details>
- <details><summary>`z = 29`</summary>
  
  - ["test/test_debug_md.ml":39:8](../test/test_debug_md.ml#L39)
  - <details><summary>`loop = 29`</summary>
    
    - ["test/test_debug_md.ml":34:24-40:9](../test/test_debug_md.ml#L34)
    - `depth = 1`
    - `x = ((first 43) (second 24))`
    - <details><summary>`y = 30`</summary>
      
      - ["test/test_debug_md.ml":38:8](../test/test_debug_md.ml#L38)
      - <details><summary>`loop = 30`</summary>
        
        - ["test/test_debug_md.ml":34:24-40:9](../test/test_debug_md.ml#L34)
        - `depth = 2`
        - `x = ((first 23) (second 45))`
        - <details><summary>`loop = 30`</summary>
          
          - ["test/test_debug_md.ml":34:24-40:9](../test/test_debug_md.ml#L34)
          - `depth = 3`
          - `x = ((first 46) (second 11))`
          - <details><summary>`loop = 30`</summary>
            
            - ["test/test_debug_md.ml":34:24-40:9](../test/test_debug_md.ml#L34)
            - `depth = 4`
            - `x = ((first 12) (second 23))`
            - <details><summary>`loop = 30`</summary>
              
              - ["test/test_debug_md.ml":34:24-40:9](../test/test_debug_md.ml#L34)
              - `depth = 5`
              - `x = ((first 24) (second 6))`
              </details>
            </details>
          </details>
        </details>
      </details>
    - <details><summary>`z = 22`</summary>
      
      - ["test/test_debug_md.ml":39:8](../test/test_debug_md.ml#L39)
      - <details><summary>`loop = 22`</summary>
        
        - ["test/test_debug_md.ml":34:24-40:9](../test/test_debug_md.ml#L34)
        - `depth = 2`
        - `x = ((first 25) (second 30))`
        - <details><summary>`loop = 22`</summary>
          
          - ["test/test_debug_md.ml":34:24-40:9](../test/test_debug_md.ml#L34)
          - `depth = 3`
          - `x = ((first 31) (second 12))`
          - <details><summary>`loop = 22`</summary>
            
            - ["test/test_debug_md.ml":34:24-40:9](../test/test_debug_md.ml#L34)
            - `depth = 4`
            - `x = ((first 13) (second 15))`
            - <details><summary>`loop = 22`</summary>
              
              - ["test/test_debug_md.ml":34:24-40:9](../test/test_debug_md.ml#L34)
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

