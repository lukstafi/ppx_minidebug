
BEGIN DEBUG SESSION

HTML CONFIG: values_first_mode=true hyperlink=../

<details><summary><span style="font-family: monospace">foo = (7 8 16)</span></summary>

- ["test/test_debug_md.ml":8:19-10:17](../test/test_debug_md.ml#L8)
- <span style="font-family: monospace">x = 7</span>
- <details><summary><span style="font-family: monospace">y = 8</span></summary>
  
  - ["test/test_debug_md.ml":9:6](../test/test_debug_md.ml#L9)
  </details>
</details>

<details><summary><span style="font-family: monospace">bar = 336</span></summary>

- ["test/test_debug_md.ml":16:19-18:14](../test/test_debug_md.ml#L16)
- <span style="font-family: monospace">x = ((first 7) (second 42))</span>
- <details><summary><span style="font-family: monospace">y = 8</span></summary>
  
  - ["test/test_debug_md.ml":17:6](../test/test_debug_md.ml#L17)
  </details>
</details>

<details><summary><span style="font-family: monospace">baz = 359</span></summary>

- ["test/test_debug_md.ml":22:19-25:28](../test/test_debug_md.ml#L22)
- <span style="font-family: monospace">x = ((first 7) (second 42))</span>
- <details><summary><span style="font-family: monospace">_yz = (8 3)</span></summary>
  
  - ["test/test_debug_md.ml":23:17](../test/test_debug_md.ml#L23)
  </details>
- <details><summary><span style="font-family: monospace">_uw = (7 13)</span></summary>
  
  - ["test/test_debug_md.ml":24:17](../test/test_debug_md.ml#L24)
  </details>
</details>

<details><summary><span style="font-family: monospace">lab = (7 8 16)</span></summary>

- ["test/test_debug_md.ml":29:19-31:17](../test/test_debug_md.ml#L29)
- <span style="font-family: monospace">x = 7</span>
- <details><summary><span style="font-family: monospace">y = 8</span></summary>
  
  - ["test/test_debug_md.ml":30:6](../test/test_debug_md.ml#L30)
  </details>
</details>

<details><summary><span style="font-family: monospace">loop = 36</span></summary>

- ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
- <span style="font-family: monospace">depth = 0</span>
- <span style="font-family: monospace">x = ((first 7) (second 42))</span>
- <details><summary><span style="font-family: monospace">y = 24</span></summary>
  
  - ["test/test_debug_md.ml":39:8](../test/test_debug_md.ml#L39)
  - <details><summary><span style="font-family: monospace">loop = 24</span></summary>
    
    - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
    - <span style="font-family: monospace">depth = 1</span>
    - <span style="font-family: monospace">x = ((first 41) (second 9))</span>
    - <details><summary><span style="font-family: monospace">y = 25</span></summary>
      
      - ["test/test_debug_md.ml":39:8](../test/test_debug_md.ml#L39)
      - <details><summary><span style="font-family: monospace">loop = 25</span></summary>
        
        - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
        - <span style="font-family: monospace">depth = 2</span>
        - <span style="font-family: monospace">x = ((first 8) (second 43))</span>
        - <details><summary><span style="font-family: monospace">loop = 25</span></summary>
          
          - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
          - <span style="font-family: monospace">depth = 3</span>
          - <span style="font-family: monospace">x = ((first 44) (second 4))</span>
          - <details><summary><span style="font-family: monospace">loop = 25</span></summary>
            
            - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
            - <span style="font-family: monospace">depth = 4</span>
            - <span style="font-family: monospace">x = ((first 5) (second 22))</span>
            - <details><summary><span style="font-family: monospace">loop = 25</span></summary>
              
              - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
              - <span style="font-family: monospace">depth = 5</span>
              - <span style="font-family: monospace">x = ((first 23) (second 2))</span>
              </details>
            </details>
          </details>
        </details>
      </details>
    - <details><summary><span style="font-family: monospace">z = 17</span></summary>
      
      - ["test/test_debug_md.ml":40:8](../test/test_debug_md.ml#L40)
      - <details><summary><span style="font-family: monospace">loop = 17</span></summary>
        
        - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
        - <span style="font-family: monospace">depth = 2</span>
        - <span style="font-family: monospace">x = ((first 10) (second 25))</span>
        - <details><summary><span style="font-family: monospace">loop = 17</span></summary>
          
          - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
          - <span style="font-family: monospace">depth = 3</span>
          - <span style="font-family: monospace">x = ((first 26) (second 5))</span>
          - <details><summary><span style="font-family: monospace">loop = 17</span></summary>
            
            - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
            - <span style="font-family: monospace">depth = 4</span>
            - <span style="font-family: monospace">x = ((first 6) (second 13))</span>
            - <details><summary><span style="font-family: monospace">loop = 17</span></summary>
              
              - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
              - <span style="font-family: monospace">depth = 5</span>
              - <span style="font-family: monospace">x = ((first 14) (second 3))</span>
              </details>
            </details>
          </details>
        </details>
      </details>
    </details>
  </details>
- <details><summary><span style="font-family: monospace">z = 29</span></summary>
  
  - ["test/test_debug_md.ml":40:8](../test/test_debug_md.ml#L40)
  - <details><summary><span style="font-family: monospace">loop = 29</span></summary>
    
    - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
    - <span style="font-family: monospace">depth = 1</span>
    - <span style="font-family: monospace">x = ((first 43) (second 24))</span>
    - <details><summary><span style="font-family: monospace">y = 30</span></summary>
      
      - ["test/test_debug_md.ml":39:8](../test/test_debug_md.ml#L39)
      - <details><summary><span style="font-family: monospace">loop = 30</span></summary>
        
        - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
        - <span style="font-family: monospace">depth = 2</span>
        - <span style="font-family: monospace">x = ((first 23) (second 45))</span>
        - <details><summary><span style="font-family: monospace">loop = 30</span></summary>
          
          - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
          - <span style="font-family: monospace">depth = 3</span>
          - <span style="font-family: monospace">x = ((first 46) (second 11))</span>
          - <details><summary><span style="font-family: monospace">loop = 30</span></summary>
            
            - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
            - <span style="font-family: monospace">depth = 4</span>
            - <span style="font-family: monospace">x = ((first 12) (second 23))</span>
            - <details><summary><span style="font-family: monospace">loop = 30</span></summary>
              
              - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
              - <span style="font-family: monospace">depth = 5</span>
              - <span style="font-family: monospace">x = ((first 24) (second 6))</span>
              </details>
            </details>
          </details>
        </details>
      </details>
    - <details><summary><span style="font-family: monospace">z = 22</span></summary>
      
      - ["test/test_debug_md.ml":40:8](../test/test_debug_md.ml#L40)
      - <details><summary><span style="font-family: monospace">loop = 22</span></summary>
        
        - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
        - <span style="font-family: monospace">depth = 2</span>
        - <span style="font-family: monospace">x = ((first 25) (second 30))</span>
        - <details><summary><span style="font-family: monospace">loop = 22</span></summary>
          
          - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
          - <span style="font-family: monospace">depth = 3</span>
          - <span style="font-family: monospace">x = ((first 31) (second 12))</span>
          - <details><summary><span style="font-family: monospace">loop = 22</span></summary>
            
            - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
            - <span style="font-family: monospace">depth = 4</span>
            - <span style="font-family: monospace">x = ((first 13) (second 15))</span>
            - <details><summary><span style="font-family: monospace">loop = 22</span></summary>
              
              - ["test/test_debug_md.ml":35:24-41:9](../test/test_debug_md.ml#L35)
              - <span style="font-family: monospace">depth = 5</span>
              - <span style="font-family: monospace">x = ((first 16) (second 6))</span>
              </details>
            </details>
          </details>
        </details>
      </details>
    </details>
  </details>
</details>

