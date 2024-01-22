
<details><summary>propagate_shapes</summary>

- ["lib/shape.ml":574:32-584:14](./lib/shape.ml#L574)
- <details><summary>update_step =</summary>
  
  - ```
    (shape
     ((batch
       ((dims ()) (bcast (Row_var (Row_var 80))) (id ((sh_id 35) (kind Batch)))))
      (input
       ((dims ()) (bcast (Row_var (Row_var 81))) (id ((sh_id 35) (kind Input)))))
      (output
       ((dims ()) (bcast (Row_var (Row_var 82))) (id ((sh_id 35) (kind Output)))))
      (id 35) (debug_name n35)))
    ```
    
  - <details><summary><span style="font-family: monospace">logic</span></summary>
    
    - <details><summary><span style="font-family: monospace">Broadcast</span></summary>
      
      - `Compose`
      - ```
        ((batch ((dims ()) (bcast Broadcastable) (id ((sh_id 12) (kind Batch)))))
         (input
          ((dims ()) (bcast (Row_var (Row_var 8))) (id ((sh_id 12) (kind Input)))))
         (output
          ((dims ()) (bcast (Row_var (Row_var 9))) (id ((sh_id 12) (kind Output)))))
         (id 12) (debug_name w3))
        ```
        
      - ```
        ((batch
          ((dims ((Dim (d 64) (label ()) (proj_id ()))))
           (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch)))))
         (input
          ((dims ()) (bcast (Row_var (Row_var 74))) (id ((sh_id 33) (kind Input)))))
         (output
          ((dims ((Dim (d 16) (label ()) (proj_id ()))))
           (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output)))))
         (id 33) (debug_name r))
        ```
        
      </details>
    </details>
  - `(id (Update_id 24))`
  </details>
- <details><summary>_debug_step =</summary>
  
  - ["lib/shape.ml":577:6](./lib/shape.ml#L577)
  - <details><summary><returns></summary>
    
    - ```
      (shape
       ((batch
         ((dims ()) (bcast (Row_var (Row_var 80))) (id ((sh_id 35) (kind Batch)))))
        (input
         ((dims ()) (bcast (Row_var (Row_var 81))) (id ((sh_id 35) (kind Input)))))
        (output
         ((dims ()) (bcast (Row_var (Row_var 82))) (id ((sh_id 35) (kind Output)))))
        (id 35) (debug_name n35)))
      ```
      
    - <details><summary><span style="font-family: monospace">logic</span></summary>
      
      - <details><summary><span style="font-family: monospace">Broadcast</span></summary>
        
        - `Compose`
        - ```
          ((batch ((dims ()) (bcast Broadcastable) (id ((sh_id 12) (kind Batch)))))
           (input
            ((dims ()) (bcast (Row_var (Row_var 8))) (id ((sh_id 12) (kind Input)))))
           (output
            ((dims ()) (bcast (Row_var (Row_var 9))) (id ((sh_id 12) (kind Output)))))
           (id 12) (debug_name w3))
          ```
          
        - ```
          ((batch
            ((dims ((Dim (d 64) (label ()) (proj_id ()))))
             (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch)))))
           (input
            ((dims ()) (bcast (Row_var (Row_var 74))) (id ((sh_id 33) (kind Input)))))
           (output
            ((dims ((Dim (d 16) (label ()) (proj_id ()))))
             (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output)))))
           (id 33) (debug_name r))
          ```
          
        </details>
      </details>
    - `(id (Update_id 24))`
    </details>
  </details>
- <details><summary>solve_inequalities =</summary>
  
  - ["lib/row.ml":685:34-727:17](./lib/row.ml#L685)
  - <details><summary><returns></summary>
    
    - `()`
    - <details><summary></summary>
      
      - <details><summary><span style="font-family: monospace">dim_env</span></summary>
        
        - <details><summary></summary>
          
          - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
          - ```
            (((id 15) (label ()))
             (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
              (lub ())))
            ```
            
          - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
          - ```
            (((id 21) (label ()))
             (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
            ```
            
          - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
          - ```
            (((id 27) (label ()))
             (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
              (lub ())))
            ```
            
          - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
          - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
          - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
          - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
          - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
          - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
          - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
          - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
          - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
          - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
          - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
          - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
          - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
          - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
          - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
          - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
          - `(((id 83) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
          - `(((id 85) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
          </details>
        </details>
      - <details><summary><span style="font-family: monospace">row_env</span></summary>
        
        - <details><summary></summary>
          
          - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
          - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
          - ```
            ((Row_var 4)
             (Solved
              ((dims ((Dim (d 2) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
            ```
            
          - ```
            ((Row_var 5)
             (Bounds (cur ((Row_var 40))) (subr ())
              (lub
               (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
            ```
            
          - ```
            ((Row_var 6)
             (Solved
              ((dims ((Dim (d 16) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
            ```
            
          - ```
            ((Row_var 7)
             (Bounds (cur ((Row_var 61))) (subr ())
              (lub
               (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
            ```
            
          - ```
            ((Row_var 8)
             (Solved
              ((dims ((Dim (d 16) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 84))) (id ((sh_id 12) (kind Input))))))
            ```
            
          - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
          - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
          - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
          - ```
            ((Row_var 12)
             (Solved
              ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
               (id ((sh_id 17) (kind Output))))))
            ```
            
          - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
          - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
          - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
          - ```
            ((Row_var 18)
             (Solved
              ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
               (id ((sh_id 19) (kind Output))))))
            ```
            
          - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
          - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
          - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
          - ```
            ((Row_var 24)
             (Solved
              ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
               (id ((sh_id 20) (kind Output))))))
            ```
            
          - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
          - ```
            ((Row_var 28)
             (Solved
              ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
               (id ((sh_id 21) (kind Batch))))))
            ```
            
          - ```
            ((Row_var 29)
             (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
            ```
            
          - ```
            ((Row_var 30)
             (Solved
              ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
               (id ((sh_id 21) (kind Output))))))
            ```
            
          - ```
            ((Row_var 33)
             (Solved
              ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
               (id ((sh_id 22) (kind Batch))))))
            ```
            
          - ```
            ((Row_var 34)
             (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
            ```
            
          - ```
            ((Row_var 35)
             (Solved
              ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
               (id ((sh_id 22) (kind Output))))))
            ```
            
          - ```
            ((Row_var 38)
             (Solved
              ((dims ((Dim (d 64) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
            ```
            
          - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
          - ```
            ((Row_var 40)
             (Bounds (cur ()) (subr ((Row_var 5)))
              (lub
               (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
            ```
            
          - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
          - ```
            ((Row_var 45)
             (Solved
              ((dims ((Dim (d 64) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
            ```
            
          - ```
            ((Row_var 46)
             (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
            ```
            
          - ```
            ((Row_var 47)
             (Solved
              ((dims ((Dim (d 16) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
            ```
            
          - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
          - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
          - ```
            ((Row_var 52)
             (Solved
              ((dims ((Dim (d 64) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
            ```
            
          - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
          - ```
            ((Row_var 54)
             (Solved
              ((dims ((Dim (d 16) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
            ```
            
          - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
          - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
          - ```
            ((Row_var 59)
             (Solved
              ((dims ((Dim (d 64) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
            ```
            
          - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
          - ```
            ((Row_var 61)
             (Bounds (cur ()) (subr ((Row_var 7)))
              (lub
               (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
            ```
            
          - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
          - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
          - ```
            ((Row_var 66)
             (Solved
              ((dims ((Dim (d 64) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
            ```
            
          - ```
            ((Row_var 67)
             (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
            ```
            
          - ```
            ((Row_var 68)
             (Solved
              ((dims ((Dim (d 16) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
            ```
            
          - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
          - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
          - ```
            ((Row_var 73)
             (Solved
              ((dims ((Dim (d 64) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
            ```
            
          - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
          - ```
            ((Row_var 75)
             (Solved
              ((dims ((Dim (d 16) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
            ```
            
          - `((Row_var 77) (Bounds (cur ((Row_var 86))) (subr ((Row_var 70))) (lub ())))`
          - `((Row_var 79) (Bounds (cur ((Row_var 84))) (subr ((Row_var 72))) (lub ())))`
          - ```
            ((Row_var 80)
             (Solved
              ((dims ((Dim (d 64) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 86))) (id ((sh_id 35) (kind Batch))))))
            ```
            
          - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
          - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
          - `((Row_var 84) (Bounds (cur ()) (subr ((Row_var 79))) (lub ())))`
          - `((Row_var 86) (Bounds (cur ()) (subr ((Row_var 77))) (lub ())))`
          </details>
        </details>
      </details>
    </details>
  - `finish = false`
  - <details><summary>ineqs =</summary>
    
    - ```
      (Row_ineq
       (cur
        ((dims ()) (bcast (Row_var (Row_var 8))) (id ((sh_id 12) (kind Input)))))
       (subr
        ((dims ((Dim (d 16) (label ()) (proj_id ()))))
         (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
      ```
      
    - ```
      (Row_ineq
       (cur
        ((dims ()) (bcast (Row_var (Row_var 80))) (id ((sh_id 35) (kind Batch)))))
       (subr ((dims ()) (bcast Broadcastable) (id ((sh_id 12) (kind Batch))))))
      ```
      
    - ```
      (Row_ineq
       (cur
        ((dims ()) (bcast (Row_var (Row_var 80))) (id ((sh_id 35) (kind Batch)))))
       (subr
        ((dims ((Dim (d 64) (label ()) (proj_id ()))))
         (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
      ```
      
    - ```
      (Row_ineq
       (cur
        ((dims ()) (bcast (Row_var (Row_var 81))) (id ((sh_id 35) (kind Input)))))
       (subr
        ((dims ()) (bcast (Row_var (Row_var 74))) (id ((sh_id 33) (kind Input))))))
      ```
      
    - ```
      (Row_ineq
       (cur
        ((dims ()) (bcast (Row_var (Row_var 82))) (id ((sh_id 35) (kind Output)))))
       (subr
        ((dims ()) (bcast (Row_var (Row_var 9))) (id ((sh_id 12) (kind Output))))))
      ```
      
    </details>
  - <details><summary>env =</summary>
    
    - <details><summary><span style="font-family: monospace">dim_env</span></summary>
      
      - <details><summary></summary>
        
        - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
        - ```
          (((id 15) (label ()))
           (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
            (lub ())))
          ```
          
        - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
        - ```
          (((id 21) (label ()))
           (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
          ```
          
        - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
        - ```
          (((id 27) (label ()))
           (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
            (lub ())))
          ```
          
        - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
        - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
        - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
        - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
        - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
        - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
        - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
        - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
        - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
        - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
        - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
        - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
        - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
        - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
        - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
        - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
        </details>
      </details>
    - <details><summary><span style="font-family: monospace">row_env</span></summary>
      
      - <details><summary></summary>
        
        - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
        - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
        - ```
          ((Row_var 4)
           (Solved
            ((dims ((Dim (d 2) (label ()) (proj_id ()))))
             (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
          ```
          
        - ```
          ((Row_var 5)
           (Bounds (cur ((Row_var 40))) (subr ())
            (lub
             (((dims ((Dim (d 16) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
          ```
          
        - ```
          ((Row_var 6)
           (Solved
            ((dims ((Dim (d 16) (label ()) (proj_id ()))))
             (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
          ```
          
        - ```
          ((Row_var 7)
           (Bounds (cur ((Row_var 61))) (subr ())
            (lub
             (((dims ((Dim (d 16) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
          ```
          
        - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
        - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
        - ```
          ((Row_var 12)
           (Solved
            ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
             (id ((sh_id 17) (kind Output))))))
          ```
          
        - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
        - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
        - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
        - ```
          ((Row_var 18)
           (Solved
            ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
             (id ((sh_id 19) (kind Output))))))
          ```
          
        - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
        - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
        - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
        - ```
          ((Row_var 24)
           (Solved
            ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
             (id ((sh_id 20) (kind Output))))))
          ```
          
        - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
        - ```
          ((Row_var 28)
           (Solved
            ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
             (id ((sh_id 21) (kind Batch))))))
          ```
          
        - ```
          ((Row_var 29)
           (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
          ```
          
        - ```
          ((Row_var 30)
           (Solved
            ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
             (id ((sh_id 21) (kind Output))))))
          ```
          
        - ```
          ((Row_var 33)
           (Solved
            ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
             (id ((sh_id 22) (kind Batch))))))
          ```
          
        - ```
          ((Row_var 34)
           (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
          ```
          
        - ```
          ((Row_var 35)
           (Solved
            ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
             (id ((sh_id 22) (kind Output))))))
          ```
          
        - ```
          ((Row_var 38)
           (Solved
            ((dims ((Dim (d 64) (label ()) (proj_id ()))))
             (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
          ```
          
        - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
        - ```
          ((Row_var 40)
           (Bounds (cur ()) (subr ((Row_var 5)))
            (lub
             (((dims ((Dim (d 16) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
          ```
          
        - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
        - ```
          ((Row_var 45)
           (Solved
            ((dims ((Dim (d 64) (label ()) (proj_id ()))))
             (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
          ```
          
        - ```
          ((Row_var 46)
           (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
          ```
          
        - ```
          ((Row_var 47)
           (Solved
            ((dims ((Dim (d 16) (label ()) (proj_id ()))))
             (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
          ```
          
        - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
        - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
        - ```
          ((Row_var 52)
           (Solved
            ((dims ((Dim (d 64) (label ()) (proj_id ()))))
             (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
          ```
          
        - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
        - ```
          ((Row_var 54)
           (Solved
            ((dims ((Dim (d 16) (label ()) (proj_id ()))))
             (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
          ```
          
        - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
        - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
        - ```
          ((Row_var 59)
           (Solved
            ((dims ((Dim (d 64) (label ()) (proj_id ()))))
             (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
          ```
          
        - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
        - ```
          ((Row_var 61)
           (Bounds (cur ()) (subr ((Row_var 7)))
            (lub
             (((dims ((Dim (d 16) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
          ```
          
        - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
        - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
        - ```
          ((Row_var 66)
           (Solved
            ((dims ((Dim (d 64) (label ()) (proj_id ()))))
             (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
          ```
          
        - ```
          ((Row_var 67)
           (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
          ```
          
        - ```
          ((Row_var 68)
           (Solved
            ((dims ((Dim (d 16) (label ()) (proj_id ()))))
             (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
          ```
          
        - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
        - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
        - ```
          ((Row_var 73)
           (Solved
            ((dims ((Dim (d 64) (label ()) (proj_id ()))))
             (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
          ```
          
        - `((Row_var 74) (Bounds (cur ()) (subr ((Row_var 67))) (lub ())))`
        - ```
          ((Row_var 75)
           (Solved
            ((dims ((Dim (d 16) (label ()) (proj_id ()))))
             (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
          ```
          
        - `((Row_var 77) (Bounds (cur ()) (subr ((Row_var 70))) (lub ())))`
        - `((Row_var 79) (Bounds (cur ()) (subr ((Row_var 72))) (lub ())))`
        </details>
      </details>
    </details>
  - <details><summary>solve =</summary>
    
    - ["lib/row.ml":687:16-725:25](./lib/row.ml#L687)
    - <details><summary><returns></summary>
      
      - `()`
      - <details><summary></summary>
        
        - <details><summary><span style="font-family: monospace">dim_env</span></summary>
          
          - <details><summary></summary>
            
            - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
            - ```
              (((id 15) (label ()))
               (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                (lub ())))
              ```
              
            - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
            - ```
              (((id 21) (label ()))
               (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
              ```
              
            - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
            - ```
              (((id 27) (label ()))
               (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                (lub ())))
              ```
              
            - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
            - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
            - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
            - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 83) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 85) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            </details>
          </details>
        - <details><summary><span style="font-family: monospace">row_env</span></summary>
          
          - <details><summary></summary>
            
            - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
            - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
            - ```
              ((Row_var 4)
               (Solved
                ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
              ```
              
            - ```
              ((Row_var 5)
               (Bounds (cur ((Row_var 40))) (subr ())
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
              ```
              
            - ```
              ((Row_var 6)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
              ```
              
            - ```
              ((Row_var 7)
               (Bounds (cur ((Row_var 61))) (subr ())
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
              ```
              
            - ```
              ((Row_var 8)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 84))) (id ((sh_id 12) (kind Input))))))
              ```
              
            - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
            - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
            - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
            - ```
              ((Row_var 12)
               (Solved
                ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                 (id ((sh_id 17) (kind Output))))))
              ```
              
            - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
            - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
            - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
            - ```
              ((Row_var 18)
               (Solved
                ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                 (id ((sh_id 19) (kind Output))))))
              ```
              
            - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
            - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
            - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
            - ```
              ((Row_var 24)
               (Solved
                ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                 (id ((sh_id 20) (kind Output))))))
              ```
              
            - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
            - ```
              ((Row_var 28)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 21) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 29)
               (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
              ```
              
            - ```
              ((Row_var 30)
               (Solved
                ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 21) (kind Output))))))
              ```
              
            - ```
              ((Row_var 33)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 22) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 34)
               (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
              ```
              
            - ```
              ((Row_var 35)
               (Solved
                ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 22) (kind Output))))))
              ```
              
            - ```
              ((Row_var 38)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
              ```
              
            - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
            - ```
              ((Row_var 40)
               (Bounds (cur ()) (subr ((Row_var 5)))
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
              ```
              
            - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
            - ```
              ((Row_var 45)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 46)
               (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
              ```
              
            - ```
              ((Row_var 47)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
              ```
              
            - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
            - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
            - ```
              ((Row_var 52)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
              ```
              
            - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
            - ```
              ((Row_var 54)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
              ```
              
            - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
            - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
            - ```
              ((Row_var 59)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
              ```
              
            - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
            - ```
              ((Row_var 61)
               (Bounds (cur ()) (subr ((Row_var 7)))
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
              ```
              
            - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
            - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
            - ```
              ((Row_var 66)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 67)
               (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
              ```
              
            - ```
              ((Row_var 68)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
              ```
              
            - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
            - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
            - ```
              ((Row_var 73)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
              ```
              
            - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
            - ```
              ((Row_var 75)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
              ```
              
            - `((Row_var 77) (Bounds (cur ((Row_var 86))) (subr ((Row_var 70))) (lub ())))`
            - `((Row_var 79) (Bounds (cur ((Row_var 84))) (subr ((Row_var 72))) (lub ())))`
            - ```
              ((Row_var 80)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 86))) (id ((sh_id 35) (kind Batch))))))
              ```
              
            - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
            - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
            - `((Row_var 84) (Bounds (cur ()) (subr ((Row_var 79))) (lub ())))`
            - `((Row_var 86) (Bounds (cur ()) (subr ((Row_var 77))) (lub ())))`
            </details>
          </details>
        </details>
      </details>
    - <details><summary>ineqs =</summary>
      
      - ```
        (Row_ineq
         (cur
          ((dims ()) (bcast (Row_var (Row_var 8))) (id ((sh_id 12) (kind Input)))))
         (subr
          ((dims ((Dim (d 16) (label ()) (proj_id ()))))
           (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
        ```
        
      - ```
        (Row_ineq
         (cur
          ((dims ()) (bcast (Row_var (Row_var 80))) (id ((sh_id 35) (kind Batch)))))
         (subr ((dims ()) (bcast Broadcastable) (id ((sh_id 12) (kind Batch))))))
        ```
        
      - ```
        (Row_ineq
         (cur
          ((dims ()) (bcast (Row_var (Row_var 80))) (id ((sh_id 35) (kind Batch)))))
         (subr
          ((dims ((Dim (d 64) (label ()) (proj_id ()))))
           (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
        ```
        
      - ```
        (Row_ineq
         (cur
          ((dims ()) (bcast (Row_var (Row_var 81))) (id ((sh_id 35) (kind Input)))))
         (subr
          ((dims ()) (bcast (Row_var (Row_var 74))) (id ((sh_id 33) (kind Input))))))
        ```
        
      - ```
        (Row_ineq
         (cur
          ((dims ()) (bcast (Row_var (Row_var 82))) (id ((sh_id 35) (kind Output)))))
         (subr
          ((dims ()) (bcast (Row_var (Row_var 9))) (id ((sh_id 12) (kind Output))))))
        ```
        
      </details>
    - <details><summary>env =</summary>
      
      - <details><summary><span style="font-family: monospace">dim_env</span></summary>
        
        - <details><summary></summary>
          
          - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
          - ```
            (((id 15) (label ()))
             (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
              (lub ())))
            ```
            
          - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
          - ```
            (((id 21) (label ()))
             (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
            ```
            
          - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
          - ```
            (((id 27) (label ()))
             (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
              (lub ())))
            ```
            
          - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
          - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
          - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
          - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
          - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
          - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
          - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
          - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
          - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
          - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
          - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
          - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
          - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
          - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
          - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
          - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
          </details>
        </details>
      - <details><summary><span style="font-family: monospace">row_env</span></summary>
        
        - <details><summary></summary>
          
          - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
          - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
          - ```
            ((Row_var 4)
             (Solved
              ((dims ((Dim (d 2) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
            ```
            
          - ```
            ((Row_var 5)
             (Bounds (cur ((Row_var 40))) (subr ())
              (lub
               (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
            ```
            
          - ```
            ((Row_var 6)
             (Solved
              ((dims ((Dim (d 16) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
            ```
            
          - ```
            ((Row_var 7)
             (Bounds (cur ((Row_var 61))) (subr ())
              (lub
               (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
            ```
            
          - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
          - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
          - ```
            ((Row_var 12)
             (Solved
              ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
               (id ((sh_id 17) (kind Output))))))
            ```
            
          - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
          - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
          - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
          - ```
            ((Row_var 18)
             (Solved
              ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
               (id ((sh_id 19) (kind Output))))))
            ```
            
          - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
          - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
          - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
          - ```
            ((Row_var 24)
             (Solved
              ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
               (id ((sh_id 20) (kind Output))))))
            ```
            
          - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
          - ```
            ((Row_var 28)
             (Solved
              ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
               (id ((sh_id 21) (kind Batch))))))
            ```
            
          - ```
            ((Row_var 29)
             (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
            ```
            
          - ```
            ((Row_var 30)
             (Solved
              ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
               (id ((sh_id 21) (kind Output))))))
            ```
            
          - ```
            ((Row_var 33)
             (Solved
              ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
               (id ((sh_id 22) (kind Batch))))))
            ```
            
          - ```
            ((Row_var 34)
             (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
            ```
            
          - ```
            ((Row_var 35)
             (Solved
              ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
               (id ((sh_id 22) (kind Output))))))
            ```
            
          - ```
            ((Row_var 38)
             (Solved
              ((dims ((Dim (d 64) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
            ```
            
          - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
          - ```
            ((Row_var 40)
             (Bounds (cur ()) (subr ((Row_var 5)))
              (lub
               (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
            ```
            
          - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
          - ```
            ((Row_var 45)
             (Solved
              ((dims ((Dim (d 64) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
            ```
            
          - ```
            ((Row_var 46)
             (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
            ```
            
          - ```
            ((Row_var 47)
             (Solved
              ((dims ((Dim (d 16) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
            ```
            
          - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
          - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
          - ```
            ((Row_var 52)
             (Solved
              ((dims ((Dim (d 64) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
            ```
            
          - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
          - ```
            ((Row_var 54)
             (Solved
              ((dims ((Dim (d 16) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
            ```
            
          - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
          - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
          - ```
            ((Row_var 59)
             (Solved
              ((dims ((Dim (d 64) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
            ```
            
          - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
          - ```
            ((Row_var 61)
             (Bounds (cur ()) (subr ((Row_var 7)))
              (lub
               (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
            ```
            
          - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
          - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
          - ```
            ((Row_var 66)
             (Solved
              ((dims ((Dim (d 64) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
            ```
            
          - ```
            ((Row_var 67)
             (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
            ```
            
          - ```
            ((Row_var 68)
             (Solved
              ((dims ((Dim (d 16) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
            ```
            
          - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
          - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
          - ```
            ((Row_var 73)
             (Solved
              ((dims ((Dim (d 64) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
            ```
            
          - `((Row_var 74) (Bounds (cur ()) (subr ((Row_var 67))) (lub ())))`
          - ```
            ((Row_var 75)
             (Solved
              ((dims ((Dim (d 16) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
            ```
            
          - `((Row_var 77) (Bounds (cur ()) (subr ((Row_var 70))) (lub ())))`
          - `((Row_var 79) (Bounds (cur ()) (subr ((Row_var 72))) (lub ())))`
          </details>
        </details>
      </details>
    - <details><summary>solve_row_ineq =</summary>
      
      - ["lib/row.ml":515:30-651:102](./lib/row.ml#L515)
      - <details><summary><returns></summary>
        
        - <details><summary></summary>
          
          - ```
            (Row_eq
             (r1
              ((dims ()) (bcast (Row_var (Row_var 8))) (id ((sh_id 12) (kind Input)))))
             (r2
              ((dims ((Var ((id 83) (label ()))))) (bcast (Row_var (Row_var 84)))
               (id ((sh_id 12) (kind Input))))))
            ```
            
          - ```
            (Row_ineq
             (cur
              ((dims ((Var ((id 83) (label ()))))) (bcast (Row_var (Row_var 84)))
               (id ((sh_id 12) (kind Input)))))
             (subr
              ((dims ((Dim (d 16) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
            ```
            
          - ```
            (Dim_ineq (cur (Var ((id 83) (label ()))))
             (subr (Dim (d 16) (label ()) (proj_id ()))))
            ```
            
          </details>
        - <details><summary></summary>
          
          - <details><summary><span style="font-family: monospace">dim_env</span></summary>
            
            - <details><summary></summary>
              
              - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
              - ```
                (((id 15) (label ()))
                 (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                  (lub ())))
                ```
                
              - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
              - ```
                (((id 21) (label ()))
                 (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                ```
                
              - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
              - ```
                (((id 27) (label ()))
                 (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                  (lub ())))
                ```
                
              - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
              - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
              - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
              - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              </details>
            </details>
          - <details><summary><span style="font-family: monospace">row_env</span></summary>
            
            - <details><summary></summary>
              
              - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
              - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
              - ```
                ((Row_var 4)
                 (Solved
                  ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                ```
                
              - ```
                ((Row_var 5)
                 (Bounds (cur ((Row_var 40))) (subr ())
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                ```
                
              - ```
                ((Row_var 6)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                ```
                
              - ```
                ((Row_var 7)
                 (Bounds (cur ((Row_var 61))) (subr ())
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                ```
                
              - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
              - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
              - ```
                ((Row_var 12)
                 (Solved
                  ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                   (id ((sh_id 17) (kind Output))))))
                ```
                
              - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
              - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
              - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
              - ```
                ((Row_var 18)
                 (Solved
                  ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                   (id ((sh_id 19) (kind Output))))))
                ```
                
              - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
              - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
              - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
              - ```
                ((Row_var 24)
                 (Solved
                  ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                   (id ((sh_id 20) (kind Output))))))
                ```
                
              - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
              - ```
                ((Row_var 28)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 21) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 29)
                 (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                ```
                
              - ```
                ((Row_var 30)
                 (Solved
                  ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 21) (kind Output))))))
                ```
                
              - ```
                ((Row_var 33)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 22) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 34)
                 (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                ```
                
              - ```
                ((Row_var 35)
                 (Solved
                  ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 22) (kind Output))))))
                ```
                
              - ```
                ((Row_var 38)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                ```
                
              - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
              - ```
                ((Row_var 40)
                 (Bounds (cur ()) (subr ((Row_var 5)))
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                ```
                
              - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
              - ```
                ((Row_var 45)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 46)
                 (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                ```
                
              - ```
                ((Row_var 47)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                ```
                
              - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
              - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
              - ```
                ((Row_var 52)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                ```
                
              - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
              - ```
                ((Row_var 54)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                ```
                
              - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
              - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
              - ```
                ((Row_var 59)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                ```
                
              - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
              - ```
                ((Row_var 61)
                 (Bounds (cur ()) (subr ((Row_var 7)))
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                ```
                
              - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
              - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
              - ```
                ((Row_var 66)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 67)
                 (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                ```
                
              - ```
                ((Row_var 68)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                ```
                
              - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
              - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
              - ```
                ((Row_var 73)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                ```
                
              - `((Row_var 74) (Bounds (cur ()) (subr ((Row_var 67))) (lub ())))`
              - ```
                ((Row_var 75)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                ```
                
              - `((Row_var 77) (Bounds (cur ()) (subr ((Row_var 70))) (lub ())))`
              - `((Row_var 79) (Bounds (cur ()) (subr ((Row_var 72))) (lub ())))`
              </details>
            </details>
          </details>
        </details>
      - `finish = false`
      - <details><summary>cur =</summary>
        
        - `(dims ())`
        - `(bcast (Row_var (Row_var 8)))`
        - `(id ((sh_id 12) (kind Input)))`
        </details>
      - <details><summary>subr =</summary>
        
        - `(dims ((Dim (d 16) (label ()) (proj_id ()))))`
        - `(bcast (Row_var (Row_var 79)))`
        - `(id ((sh_id 33) (kind Output)))`
        </details>
      - <details><summary>env =</summary>
        
        - <details><summary><span style="font-family: monospace">dim_env</span></summary>
          
          - <details><summary></summary>
            
            - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
            - ```
              (((id 15) (label ()))
               (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                (lub ())))
              ```
              
            - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
            - ```
              (((id 21) (label ()))
               (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
              ```
              
            - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
            - ```
              (((id 27) (label ()))
               (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                (lub ())))
              ```
              
            - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
            - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
            - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
            - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            </details>
          </details>
        - <details><summary><span style="font-family: monospace">row_env</span></summary>
          
          - <details><summary></summary>
            
            - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
            - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
            - ```
              ((Row_var 4)
               (Solved
                ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
              ```
              
            - ```
              ((Row_var 5)
               (Bounds (cur ((Row_var 40))) (subr ())
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
              ```
              
            - ```
              ((Row_var 6)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
              ```
              
            - ```
              ((Row_var 7)
               (Bounds (cur ((Row_var 61))) (subr ())
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
              ```
              
            - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
            - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
            - ```
              ((Row_var 12)
               (Solved
                ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                 (id ((sh_id 17) (kind Output))))))
              ```
              
            - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
            - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
            - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
            - ```
              ((Row_var 18)
               (Solved
                ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                 (id ((sh_id 19) (kind Output))))))
              ```
              
            - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
            - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
            - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
            - ```
              ((Row_var 24)
               (Solved
                ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                 (id ((sh_id 20) (kind Output))))))
              ```
              
            - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
            - ```
              ((Row_var 28)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 21) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 29)
               (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
              ```
              
            - ```
              ((Row_var 30)
               (Solved
                ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 21) (kind Output))))))
              ```
              
            - ```
              ((Row_var 33)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 22) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 34)
               (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
              ```
              
            - ```
              ((Row_var 35)
               (Solved
                ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 22) (kind Output))))))
              ```
              
            - ```
              ((Row_var 38)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
              ```
              
            - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
            - ```
              ((Row_var 40)
               (Bounds (cur ()) (subr ((Row_var 5)))
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
              ```
              
            - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
            - ```
              ((Row_var 45)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 46)
               (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
              ```
              
            - ```
              ((Row_var 47)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
              ```
              
            - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
            - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
            - ```
              ((Row_var 52)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
              ```
              
            - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
            - ```
              ((Row_var 54)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
              ```
              
            - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
            - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
            - ```
              ((Row_var 59)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
              ```
              
            - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
            - ```
              ((Row_var 61)
               (Bounds (cur ()) (subr ((Row_var 7)))
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
              ```
              
            - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
            - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
            - ```
              ((Row_var 66)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 67)
               (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
              ```
              
            - ```
              ((Row_var 68)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
              ```
              
            - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
            - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
            - ```
              ((Row_var 73)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
              ```
              
            - `((Row_var 74) (Bounds (cur ()) (subr ((Row_var 67))) (lub ())))`
            - ```
              ((Row_var 75)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
              ```
              
            - `((Row_var 77) (Bounds (cur ()) (subr ((Row_var 70))) (lub ())))`
            - `((Row_var 79) (Bounds (cur ()) (subr ((Row_var 72))) (lub ())))`
            </details>
          </details>
        </details>
      - <details><summary><match -- branch 3></summary>
        
        - ["lib/row.ml":587:4](./lib/row.ml#L587)
        - <details><summary><span style="font-family: monospace">more_dims = ((Var ((id 83) (label ()))))</span></summary>
          
          - ["lib/row.ml":588:10](./lib/row.ml#L588)
          - <details><summary>__fun</summary>
            
            - ["lib/row.ml":588:77-588:104](./lib/row.ml#L588)
            </details>
          </details>
        - <details><summary>template =</summary>
          
          - ["lib/row.ml":590:10](./lib/row.ml#L590)
          - <details><summary><returns></summary>
            
            - `(dims ((Var ((id 83) (label ())))))`
            - `(bcast (Row_var (Row_var 84)))`
            - `(id ((sh_id 12) (kind Input)))`
            </details>
          </details>
        - <details><summary><span style="font-family: monospace">subr_dims = ((Dim (d 16) (label ()) (proj_id ())))</span></summary>
          
          - ["lib/row.ml":591:10](./lib/row.ml#L591)
          </details>
        - <details><summary>__fun</summary>
          
          - ["lib/row.ml":594:48-594:88](./lib/row.ml#L594)
          </details>
        </details>
      </details>
    - <details><summary>solve_row_ineq =</summary>
      
      - ["lib/row.ml":515:30-651:102](./lib/row.ml#L515)
      - <details><summary><returns></summary>
        
        - `()`
        - <details><summary></summary>
          
          - <details><summary><span style="font-family: monospace">dim_env</span></summary>
            
            - <details><summary></summary>
              
              - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
              - ```
                (((id 15) (label ()))
                 (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                  (lub ())))
                ```
                
              - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
              - ```
                (((id 21) (label ()))
                 (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                ```
                
              - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
              - ```
                (((id 27) (label ()))
                 (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                  (lub ())))
                ```
                
              - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
              - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
              - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
              - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              </details>
            </details>
          - <details><summary><span style="font-family: monospace">row_env</span></summary>
            
            - <details><summary></summary>
              
              - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
              - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
              - ```
                ((Row_var 4)
                 (Solved
                  ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                ```
                
              - ```
                ((Row_var 5)
                 (Bounds (cur ((Row_var 40))) (subr ())
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                ```
                
              - ```
                ((Row_var 6)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                ```
                
              - ```
                ((Row_var 7)
                 (Bounds (cur ((Row_var 61))) (subr ())
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                ```
                
              - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
              - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
              - ```
                ((Row_var 12)
                 (Solved
                  ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                   (id ((sh_id 17) (kind Output))))))
                ```
                
              - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
              - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
              - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
              - ```
                ((Row_var 18)
                 (Solved
                  ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                   (id ((sh_id 19) (kind Output))))))
                ```
                
              - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
              - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
              - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
              - ```
                ((Row_var 24)
                 (Solved
                  ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                   (id ((sh_id 20) (kind Output))))))
                ```
                
              - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
              - ```
                ((Row_var 28)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 21) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 29)
                 (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                ```
                
              - ```
                ((Row_var 30)
                 (Solved
                  ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 21) (kind Output))))))
                ```
                
              - ```
                ((Row_var 33)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 22) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 34)
                 (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                ```
                
              - ```
                ((Row_var 35)
                 (Solved
                  ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 22) (kind Output))))))
                ```
                
              - ```
                ((Row_var 38)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                ```
                
              - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
              - ```
                ((Row_var 40)
                 (Bounds (cur ()) (subr ((Row_var 5)))
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                ```
                
              - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
              - ```
                ((Row_var 45)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 46)
                 (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                ```
                
              - ```
                ((Row_var 47)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                ```
                
              - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
              - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
              - ```
                ((Row_var 52)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                ```
                
              - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
              - ```
                ((Row_var 54)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                ```
                
              - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
              - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
              - ```
                ((Row_var 59)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                ```
                
              - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
              - ```
                ((Row_var 61)
                 (Bounds (cur ()) (subr ((Row_var 7)))
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                ```
                
              - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
              - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
              - ```
                ((Row_var 66)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 67)
                 (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                ```
                
              - ```
                ((Row_var 68)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                ```
                
              - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
              - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
              - ```
                ((Row_var 73)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                ```
                
              - `((Row_var 74) (Bounds (cur ()) (subr ((Row_var 67))) (lub ())))`
              - ```
                ((Row_var 75)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                ```
                
              - `((Row_var 77) (Bounds (cur ()) (subr ((Row_var 70))) (lub ())))`
              - `((Row_var 79) (Bounds (cur ()) (subr ((Row_var 72))) (lub ())))`
              </details>
            </details>
          </details>
        </details>
      - `finish = false`
      - <details><summary>cur =</summary>
        
        - `(dims ())`
        - `(bcast (Row_var (Row_var 80)))`
        - `(id ((sh_id 35) (kind Batch)))`
        </details>
      - <details><summary>subr =</summary>
        
        - `(dims ())`
        - `(bcast Broadcastable)`
        - `(id ((sh_id 12) (kind Batch)))`
        </details>
      - <details><summary>env =</summary>
        
        - <details><summary><span style="font-family: monospace">dim_env</span></summary>
          
          - <details><summary></summary>
            
            - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
            - ```
              (((id 15) (label ()))
               (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                (lub ())))
              ```
              
            - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
            - ```
              (((id 21) (label ()))
               (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
              ```
              
            - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
            - ```
              (((id 27) (label ()))
               (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                (lub ())))
              ```
              
            - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
            - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
            - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
            - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            </details>
          </details>
        - <details><summary><span style="font-family: monospace">row_env</span></summary>
          
          - <details><summary></summary>
            
            - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
            - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
            - ```
              ((Row_var 4)
               (Solved
                ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
              ```
              
            - ```
              ((Row_var 5)
               (Bounds (cur ((Row_var 40))) (subr ())
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
              ```
              
            - ```
              ((Row_var 6)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
              ```
              
            - ```
              ((Row_var 7)
               (Bounds (cur ((Row_var 61))) (subr ())
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
              ```
              
            - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
            - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
            - ```
              ((Row_var 12)
               (Solved
                ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                 (id ((sh_id 17) (kind Output))))))
              ```
              
            - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
            - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
            - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
            - ```
              ((Row_var 18)
               (Solved
                ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                 (id ((sh_id 19) (kind Output))))))
              ```
              
            - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
            - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
            - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
            - ```
              ((Row_var 24)
               (Solved
                ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                 (id ((sh_id 20) (kind Output))))))
              ```
              
            - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
            - ```
              ((Row_var 28)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 21) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 29)
               (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
              ```
              
            - ```
              ((Row_var 30)
               (Solved
                ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 21) (kind Output))))))
              ```
              
            - ```
              ((Row_var 33)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 22) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 34)
               (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
              ```
              
            - ```
              ((Row_var 35)
               (Solved
                ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 22) (kind Output))))))
              ```
              
            - ```
              ((Row_var 38)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
              ```
              
            - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
            - ```
              ((Row_var 40)
               (Bounds (cur ()) (subr ((Row_var 5)))
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
              ```
              
            - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
            - ```
              ((Row_var 45)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 46)
               (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
              ```
              
            - ```
              ((Row_var 47)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
              ```
              
            - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
            - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
            - ```
              ((Row_var 52)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
              ```
              
            - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
            - ```
              ((Row_var 54)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
              ```
              
            - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
            - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
            - ```
              ((Row_var 59)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
              ```
              
            - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
            - ```
              ((Row_var 61)
               (Bounds (cur ()) (subr ((Row_var 7)))
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
              ```
              
            - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
            - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
            - ```
              ((Row_var 66)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 67)
               (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
              ```
              
            - ```
              ((Row_var 68)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
              ```
              
            - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
            - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
            - ```
              ((Row_var 73)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
              ```
              
            - `((Row_var 74) (Bounds (cur ()) (subr ((Row_var 67))) (lub ())))`
            - ```
              ((Row_var 75)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
              ```
              
            - `((Row_var 77) (Bounds (cur ()) (subr ((Row_var 70))) (lub ())))`
            - `((Row_var 79) (Bounds (cur ()) (subr ((Row_var 72))) (lub ())))`
            </details>
          </details>
        </details>
      - <details><summary><match -- branch 6></summary>
        
        - ["lib/row.ml":650:4](./lib/row.ml#L650)
        </details>
      </details>
    - <details><summary>solve_row_ineq =</summary>
      
      - ["lib/row.ml":515:30-651:102](./lib/row.ml#L515)
      - <details><summary><returns></summary>
        
        - <details><summary></summary>
          
          - ```
            (Row_eq
             (r1
              ((dims ()) (bcast (Row_var (Row_var 80))) (id ((sh_id 35) (kind Batch)))))
             (r2
              ((dims ((Var ((id 85) (label ()))))) (bcast (Row_var (Row_var 86)))
               (id ((sh_id 35) (kind Batch))))))
            ```
            
          - ```
            (Row_ineq
             (cur
              ((dims ((Var ((id 85) (label ()))))) (bcast (Row_var (Row_var 86)))
               (id ((sh_id 35) (kind Batch)))))
             (subr
              ((dims ((Dim (d 64) (label ()) (proj_id ()))))
               (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
            ```
            
          - ```
            (Dim_ineq (cur (Var ((id 85) (label ()))))
             (subr (Dim (d 64) (label ()) (proj_id ()))))
            ```
            
          </details>
        - <details><summary></summary>
          
          - <details><summary><span style="font-family: monospace">dim_env</span></summary>
            
            - <details><summary></summary>
              
              - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
              - ```
                (((id 15) (label ()))
                 (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                  (lub ())))
                ```
                
              - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
              - ```
                (((id 21) (label ()))
                 (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                ```
                
              - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
              - ```
                (((id 27) (label ()))
                 (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                  (lub ())))
                ```
                
              - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
              - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
              - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
              - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              </details>
            </details>
          - <details><summary><span style="font-family: monospace">row_env</span></summary>
            
            - <details><summary></summary>
              
              - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
              - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
              - ```
                ((Row_var 4)
                 (Solved
                  ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                ```
                
              - ```
                ((Row_var 5)
                 (Bounds (cur ((Row_var 40))) (subr ())
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                ```
                
              - ```
                ((Row_var 6)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                ```
                
              - ```
                ((Row_var 7)
                 (Bounds (cur ((Row_var 61))) (subr ())
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                ```
                
              - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
              - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
              - ```
                ((Row_var 12)
                 (Solved
                  ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                   (id ((sh_id 17) (kind Output))))))
                ```
                
              - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
              - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
              - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
              - ```
                ((Row_var 18)
                 (Solved
                  ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                   (id ((sh_id 19) (kind Output))))))
                ```
                
              - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
              - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
              - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
              - ```
                ((Row_var 24)
                 (Solved
                  ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                   (id ((sh_id 20) (kind Output))))))
                ```
                
              - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
              - ```
                ((Row_var 28)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 21) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 29)
                 (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                ```
                
              - ```
                ((Row_var 30)
                 (Solved
                  ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 21) (kind Output))))))
                ```
                
              - ```
                ((Row_var 33)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 22) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 34)
                 (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                ```
                
              - ```
                ((Row_var 35)
                 (Solved
                  ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 22) (kind Output))))))
                ```
                
              - ```
                ((Row_var 38)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                ```
                
              - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
              - ```
                ((Row_var 40)
                 (Bounds (cur ()) (subr ((Row_var 5)))
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                ```
                
              - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
              - ```
                ((Row_var 45)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 46)
                 (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                ```
                
              - ```
                ((Row_var 47)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                ```
                
              - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
              - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
              - ```
                ((Row_var 52)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                ```
                
              - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
              - ```
                ((Row_var 54)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                ```
                
              - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
              - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
              - ```
                ((Row_var 59)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                ```
                
              - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
              - ```
                ((Row_var 61)
                 (Bounds (cur ()) (subr ((Row_var 7)))
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                ```
                
              - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
              - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
              - ```
                ((Row_var 66)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 67)
                 (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                ```
                
              - ```
                ((Row_var 68)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                ```
                
              - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
              - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
              - ```
                ((Row_var 73)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                ```
                
              - `((Row_var 74) (Bounds (cur ()) (subr ((Row_var 67))) (lub ())))`
              - ```
                ((Row_var 75)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                ```
                
              - `((Row_var 77) (Bounds (cur ()) (subr ((Row_var 70))) (lub ())))`
              - `((Row_var 79) (Bounds (cur ()) (subr ((Row_var 72))) (lub ())))`
              </details>
            </details>
          </details>
        </details>
      - `finish = false`
      - <details><summary>cur =</summary>
        
        - `(dims ())`
        - `(bcast (Row_var (Row_var 80)))`
        - `(id ((sh_id 35) (kind Batch)))`
        </details>
      - <details><summary>subr =</summary>
        
        - `(dims ((Dim (d 64) (label ()) (proj_id ()))))`
        - `(bcast (Row_var (Row_var 77)))`
        - `(id ((sh_id 33) (kind Batch)))`
        </details>
      - <details><summary>env =</summary>
        
        - <details><summary><span style="font-family: monospace">dim_env</span></summary>
          
          - <details><summary></summary>
            
            - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
            - ```
              (((id 15) (label ()))
               (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                (lub ())))
              ```
              
            - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
            - ```
              (((id 21) (label ()))
               (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
              ```
              
            - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
            - ```
              (((id 27) (label ()))
               (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                (lub ())))
              ```
              
            - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
            - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
            - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
            - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            </details>
          </details>
        - <details><summary><span style="font-family: monospace">row_env</span></summary>
          
          - <details><summary></summary>
            
            - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
            - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
            - ```
              ((Row_var 4)
               (Solved
                ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
              ```
              
            - ```
              ((Row_var 5)
               (Bounds (cur ((Row_var 40))) (subr ())
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
              ```
              
            - ```
              ((Row_var 6)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
              ```
              
            - ```
              ((Row_var 7)
               (Bounds (cur ((Row_var 61))) (subr ())
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
              ```
              
            - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
            - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
            - ```
              ((Row_var 12)
               (Solved
                ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                 (id ((sh_id 17) (kind Output))))))
              ```
              
            - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
            - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
            - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
            - ```
              ((Row_var 18)
               (Solved
                ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                 (id ((sh_id 19) (kind Output))))))
              ```
              
            - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
            - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
            - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
            - ```
              ((Row_var 24)
               (Solved
                ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                 (id ((sh_id 20) (kind Output))))))
              ```
              
            - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
            - ```
              ((Row_var 28)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 21) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 29)
               (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
              ```
              
            - ```
              ((Row_var 30)
               (Solved
                ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 21) (kind Output))))))
              ```
              
            - ```
              ((Row_var 33)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 22) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 34)
               (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
              ```
              
            - ```
              ((Row_var 35)
               (Solved
                ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 22) (kind Output))))))
              ```
              
            - ```
              ((Row_var 38)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
              ```
              
            - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
            - ```
              ((Row_var 40)
               (Bounds (cur ()) (subr ((Row_var 5)))
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
              ```
              
            - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
            - ```
              ((Row_var 45)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 46)
               (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
              ```
              
            - ```
              ((Row_var 47)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
              ```
              
            - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
            - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
            - ```
              ((Row_var 52)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
              ```
              
            - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
            - ```
              ((Row_var 54)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
              ```
              
            - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
            - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
            - ```
              ((Row_var 59)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
              ```
              
            - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
            - ```
              ((Row_var 61)
               (Bounds (cur ()) (subr ((Row_var 7)))
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
              ```
              
            - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
            - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
            - ```
              ((Row_var 66)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 67)
               (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
              ```
              
            - ```
              ((Row_var 68)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
              ```
              
            - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
            - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
            - ```
              ((Row_var 73)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
              ```
              
            - `((Row_var 74) (Bounds (cur ()) (subr ((Row_var 67))) (lub ())))`
            - ```
              ((Row_var 75)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
              ```
              
            - `((Row_var 77) (Bounds (cur ()) (subr ((Row_var 70))) (lub ())))`
            - `((Row_var 79) (Bounds (cur ()) (subr ((Row_var 72))) (lub ())))`
            </details>
          </details>
        </details>
      - <details><summary><match -- branch 3></summary>
        
        - ["lib/row.ml":587:4](./lib/row.ml#L587)
        - <details><summary><span style="font-family: monospace">more_dims = ((Var ((id 85) (label ()))))</span></summary>
          
          - ["lib/row.ml":588:10](./lib/row.ml#L588)
          - <details><summary>__fun</summary>
            
            - ["lib/row.ml":588:77-588:104](./lib/row.ml#L588)
            </details>
          </details>
        - <details><summary>template =</summary>
          
          - ["lib/row.ml":590:10](./lib/row.ml#L590)
          - <details><summary><returns></summary>
            
            - `(dims ((Var ((id 85) (label ())))))`
            - `(bcast (Row_var (Row_var 86)))`
            - `(id ((sh_id 35) (kind Batch)))`
            </details>
          </details>
        - <details><summary><span style="font-family: monospace">subr_dims = ((Dim (d 64) (label ()) (proj_id ())))</span></summary>
          
          - ["lib/row.ml":591:10](./lib/row.ml#L591)
          </details>
        - <details><summary>__fun</summary>
          
          - ["lib/row.ml":594:48-594:88](./lib/row.ml#L594)
          </details>
        </details>
      </details>
    - <details><summary>solve_row_ineq =</summary>
      
      - ["lib/row.ml":515:30-651:102](./lib/row.ml#L515)
      - <details><summary><returns></summary>
        
        - `()`
        - <details><summary></summary>
          
          - <details><summary><span style="font-family: monospace">dim_env</span></summary>
            
            - <details><summary></summary>
              
              - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
              - ```
                (((id 15) (label ()))
                 (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                  (lub ())))
                ```
                
              - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
              - ```
                (((id 21) (label ()))
                 (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                ```
                
              - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
              - ```
                (((id 27) (label ()))
                 (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                  (lub ())))
                ```
                
              - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
              - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
              - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
              - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              </details>
            </details>
          - <details><summary><span style="font-family: monospace">row_env</span></summary>
            
            - <details><summary></summary>
              
              - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
              - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
              - ```
                ((Row_var 4)
                 (Solved
                  ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                ```
                
              - ```
                ((Row_var 5)
                 (Bounds (cur ((Row_var 40))) (subr ())
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                ```
                
              - ```
                ((Row_var 6)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                ```
                
              - ```
                ((Row_var 7)
                 (Bounds (cur ((Row_var 61))) (subr ())
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                ```
                
              - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
              - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
              - ```
                ((Row_var 12)
                 (Solved
                  ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                   (id ((sh_id 17) (kind Output))))))
                ```
                
              - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
              - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
              - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
              - ```
                ((Row_var 18)
                 (Solved
                  ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                   (id ((sh_id 19) (kind Output))))))
                ```
                
              - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
              - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
              - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
              - ```
                ((Row_var 24)
                 (Solved
                  ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                   (id ((sh_id 20) (kind Output))))))
                ```
                
              - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
              - ```
                ((Row_var 28)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 21) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 29)
                 (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                ```
                
              - ```
                ((Row_var 30)
                 (Solved
                  ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 21) (kind Output))))))
                ```
                
              - ```
                ((Row_var 33)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 22) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 34)
                 (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                ```
                
              - ```
                ((Row_var 35)
                 (Solved
                  ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 22) (kind Output))))))
                ```
                
              - ```
                ((Row_var 38)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                ```
                
              - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
              - ```
                ((Row_var 40)
                 (Bounds (cur ()) (subr ((Row_var 5)))
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                ```
                
              - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
              - ```
                ((Row_var 45)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 46)
                 (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                ```
                
              - ```
                ((Row_var 47)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                ```
                
              - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
              - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
              - ```
                ((Row_var 52)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                ```
                
              - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
              - ```
                ((Row_var 54)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                ```
                
              - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
              - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
              - ```
                ((Row_var 59)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                ```
                
              - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
              - ```
                ((Row_var 61)
                 (Bounds (cur ()) (subr ((Row_var 7)))
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                ```
                
              - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
              - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
              - ```
                ((Row_var 66)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 67)
                 (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                ```
                
              - ```
                ((Row_var 68)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                ```
                
              - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
              - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
              - ```
                ((Row_var 73)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                ```
                
              - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
              - ```
                ((Row_var 75)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                ```
                
              - `((Row_var 77) (Bounds (cur ()) (subr ((Row_var 70))) (lub ())))`
              - `((Row_var 79) (Bounds (cur ()) (subr ((Row_var 72))) (lub ())))`
              - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
              </details>
            </details>
          </details>
        </details>
      - `finish = false`
      - <details><summary>cur =</summary>
        
        - `(dims ())`
        - `(bcast (Row_var (Row_var 81)))`
        - `(id ((sh_id 35) (kind Input)))`
        </details>
      - <details><summary>subr =</summary>
        
        - `(dims ())`
        - `(bcast (Row_var (Row_var 74)))`
        - `(id ((sh_id 33) (kind Input)))`
        </details>
      - <details><summary>env =</summary>
        
        - <details><summary><span style="font-family: monospace">dim_env</span></summary>
          
          - <details><summary></summary>
            
            - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
            - ```
              (((id 15) (label ()))
               (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                (lub ())))
              ```
              
            - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
            - ```
              (((id 21) (label ()))
               (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
              ```
              
            - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
            - ```
              (((id 27) (label ()))
               (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                (lub ())))
              ```
              
            - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
            - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
            - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
            - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            </details>
          </details>
        - <details><summary><span style="font-family: monospace">row_env</span></summary>
          
          - <details><summary></summary>
            
            - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
            - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
            - ```
              ((Row_var 4)
               (Solved
                ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
              ```
              
            - ```
              ((Row_var 5)
               (Bounds (cur ((Row_var 40))) (subr ())
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
              ```
              
            - ```
              ((Row_var 6)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
              ```
              
            - ```
              ((Row_var 7)
               (Bounds (cur ((Row_var 61))) (subr ())
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
              ```
              
            - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
            - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
            - ```
              ((Row_var 12)
               (Solved
                ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                 (id ((sh_id 17) (kind Output))))))
              ```
              
            - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
            - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
            - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
            - ```
              ((Row_var 18)
               (Solved
                ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                 (id ((sh_id 19) (kind Output))))))
              ```
              
            - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
            - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
            - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
            - ```
              ((Row_var 24)
               (Solved
                ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                 (id ((sh_id 20) (kind Output))))))
              ```
              
            - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
            - ```
              ((Row_var 28)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 21) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 29)
               (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
              ```
              
            - ```
              ((Row_var 30)
               (Solved
                ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 21) (kind Output))))))
              ```
              
            - ```
              ((Row_var 33)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 22) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 34)
               (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
              ```
              
            - ```
              ((Row_var 35)
               (Solved
                ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 22) (kind Output))))))
              ```
              
            - ```
              ((Row_var 38)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
              ```
              
            - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
            - ```
              ((Row_var 40)
               (Bounds (cur ()) (subr ((Row_var 5)))
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
              ```
              
            - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
            - ```
              ((Row_var 45)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 46)
               (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
              ```
              
            - ```
              ((Row_var 47)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
              ```
              
            - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
            - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
            - ```
              ((Row_var 52)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
              ```
              
            - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
            - ```
              ((Row_var 54)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
              ```
              
            - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
            - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
            - ```
              ((Row_var 59)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
              ```
              
            - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
            - ```
              ((Row_var 61)
               (Bounds (cur ()) (subr ((Row_var 7)))
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
              ```
              
            - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
            - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
            - ```
              ((Row_var 66)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 67)
               (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
              ```
              
            - ```
              ((Row_var 68)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
              ```
              
            - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
            - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
            - ```
              ((Row_var 73)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
              ```
              
            - `((Row_var 74) (Bounds (cur ()) (subr ((Row_var 67))) (lub ())))`
            - ```
              ((Row_var 75)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
              ```
              
            - `((Row_var 77) (Bounds (cur ()) (subr ((Row_var 70))) (lub ())))`
            - `((Row_var 79) (Bounds (cur ()) (subr ((Row_var 72))) (lub ())))`
            </details>
          </details>
        </details>
      - <details><summary><match -- branch 2></summary>
        
        - ["lib/row.ml":533:4](./lib/row.ml#L533)
        - <details><summary><match -- branch 7></summary>
          
          - ["lib/row.ml":564:8](./lib/row.ml#L564)
          - <details><summary>__fun</summary>
            
            - ["lib/row.ml":570:48-571:90](./lib/row.ml#L570)
            - <details><summary>nonredundant</summary>
              
              - ["lib/row.ml":517:19-518:108](./lib/row.ml#L517)
              </details>
            </details>
          </details>
        </details>
      </details>
    - <details><summary>solve_row_ineq =</summary>
      
      - ["lib/row.ml":515:30-651:102](./lib/row.ml#L515)
      - <details><summary><returns></summary>
        
        - `()`
        - <details><summary></summary>
          
          - <details><summary><span style="font-family: monospace">dim_env</span></summary>
            
            - <details><summary></summary>
              
              - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
              - ```
                (((id 15) (label ()))
                 (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                  (lub ())))
                ```
                
              - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
              - ```
                (((id 21) (label ()))
                 (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                ```
                
              - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
              - ```
                (((id 27) (label ()))
                 (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                  (lub ())))
                ```
                
              - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
              - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
              - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
              - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              </details>
            </details>
          - <details><summary><span style="font-family: monospace">row_env</span></summary>
            
            - <details><summary></summary>
              
              - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
              - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
              - ```
                ((Row_var 4)
                 (Solved
                  ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                ```
                
              - ```
                ((Row_var 5)
                 (Bounds (cur ((Row_var 40))) (subr ())
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                ```
                
              - ```
                ((Row_var 6)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                ```
                
              - ```
                ((Row_var 7)
                 (Bounds (cur ((Row_var 61))) (subr ())
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                ```
                
              - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
              - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
              - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
              - ```
                ((Row_var 12)
                 (Solved
                  ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                   (id ((sh_id 17) (kind Output))))))
                ```
                
              - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
              - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
              - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
              - ```
                ((Row_var 18)
                 (Solved
                  ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                   (id ((sh_id 19) (kind Output))))))
                ```
                
              - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
              - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
              - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
              - ```
                ((Row_var 24)
                 (Solved
                  ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                   (id ((sh_id 20) (kind Output))))))
                ```
                
              - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
              - ```
                ((Row_var 28)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 21) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 29)
                 (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                ```
                
              - ```
                ((Row_var 30)
                 (Solved
                  ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 21) (kind Output))))))
                ```
                
              - ```
                ((Row_var 33)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 22) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 34)
                 (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                ```
                
              - ```
                ((Row_var 35)
                 (Solved
                  ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 22) (kind Output))))))
                ```
                
              - ```
                ((Row_var 38)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                ```
                
              - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
              - ```
                ((Row_var 40)
                 (Bounds (cur ()) (subr ((Row_var 5)))
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                ```
                
              - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
              - ```
                ((Row_var 45)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 46)
                 (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                ```
                
              - ```
                ((Row_var 47)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                ```
                
              - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
              - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
              - ```
                ((Row_var 52)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                ```
                
              - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
              - ```
                ((Row_var 54)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                ```
                
              - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
              - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
              - ```
                ((Row_var 59)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                ```
                
              - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
              - ```
                ((Row_var 61)
                 (Bounds (cur ()) (subr ((Row_var 7)))
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                ```
                
              - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
              - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
              - ```
                ((Row_var 66)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 67)
                 (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                ```
                
              - ```
                ((Row_var 68)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                ```
                
              - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
              - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
              - ```
                ((Row_var 73)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                ```
                
              - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
              - ```
                ((Row_var 75)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                ```
                
              - `((Row_var 77) (Bounds (cur ()) (subr ((Row_var 70))) (lub ())))`
              - `((Row_var 79) (Bounds (cur ()) (subr ((Row_var 72))) (lub ())))`
              - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
              - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
              </details>
            </details>
          </details>
        </details>
      - `finish = false`
      - <details><summary>cur =</summary>
        
        - `(dims ())`
        - `(bcast (Row_var (Row_var 82)))`
        - `(id ((sh_id 35) (kind Output)))`
        </details>
      - <details><summary>subr =</summary>
        
        - `(dims ())`
        - `(bcast (Row_var (Row_var 9)))`
        - `(id ((sh_id 12) (kind Output)))`
        </details>
      - <details><summary>env =</summary>
        
        - <details><summary><span style="font-family: monospace">dim_env</span></summary>
          
          - <details><summary></summary>
            
            - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
            - ```
              (((id 15) (label ()))
               (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                (lub ())))
              ```
              
            - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
            - ```
              (((id 21) (label ()))
               (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
              ```
              
            - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
            - ```
              (((id 27) (label ()))
               (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                (lub ())))
              ```
              
            - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
            - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
            - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
            - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            </details>
          </details>
        - <details><summary><span style="font-family: monospace">row_env</span></summary>
          
          - <details><summary></summary>
            
            - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
            - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
            - ```
              ((Row_var 4)
               (Solved
                ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
              ```
              
            - ```
              ((Row_var 5)
               (Bounds (cur ((Row_var 40))) (subr ())
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
              ```
              
            - ```
              ((Row_var 6)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
              ```
              
            - ```
              ((Row_var 7)
               (Bounds (cur ((Row_var 61))) (subr ())
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
              ```
              
            - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
            - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
            - ```
              ((Row_var 12)
               (Solved
                ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                 (id ((sh_id 17) (kind Output))))))
              ```
              
            - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
            - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
            - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
            - ```
              ((Row_var 18)
               (Solved
                ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                 (id ((sh_id 19) (kind Output))))))
              ```
              
            - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
            - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
            - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
            - ```
              ((Row_var 24)
               (Solved
                ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                 (id ((sh_id 20) (kind Output))))))
              ```
              
            - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
            - ```
              ((Row_var 28)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 21) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 29)
               (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
              ```
              
            - ```
              ((Row_var 30)
               (Solved
                ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 21) (kind Output))))))
              ```
              
            - ```
              ((Row_var 33)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 22) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 34)
               (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
              ```
              
            - ```
              ((Row_var 35)
               (Solved
                ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 22) (kind Output))))))
              ```
              
            - ```
              ((Row_var 38)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
              ```
              
            - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
            - ```
              ((Row_var 40)
               (Bounds (cur ()) (subr ((Row_var 5)))
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
              ```
              
            - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
            - ```
              ((Row_var 45)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 46)
               (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
              ```
              
            - ```
              ((Row_var 47)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
              ```
              
            - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
            - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
            - ```
              ((Row_var 52)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
              ```
              
            - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
            - ```
              ((Row_var 54)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
              ```
              
            - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
            - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
            - ```
              ((Row_var 59)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
              ```
              
            - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
            - ```
              ((Row_var 61)
               (Bounds (cur ()) (subr ((Row_var 7)))
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
              ```
              
            - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
            - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
            - ```
              ((Row_var 66)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 67)
               (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
              ```
              
            - ```
              ((Row_var 68)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
              ```
              
            - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
            - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
            - ```
              ((Row_var 73)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
              ```
              
            - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
            - ```
              ((Row_var 75)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
              ```
              
            - `((Row_var 77) (Bounds (cur ()) (subr ((Row_var 70))) (lub ())))`
            - `((Row_var 79) (Bounds (cur ()) (subr ((Row_var 72))) (lub ())))`
            - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
            </details>
          </details>
        </details>
      - <details><summary><match -- branch 2></summary>
        
        - ["lib/row.ml":533:4](./lib/row.ml#L533)
        - <details><summary><match -- branch 5></summary>
          
          - ["lib/row.ml":545:8](./lib/row.ml#L545)
          </details>
        </details>
      </details>
    - <details><summary>solve =</summary>
      
      - ["lib/row.ml":687:16-725:25](./lib/row.ml#L687)
      - <details><summary><returns></summary>
        
        - `()`
        - <details><summary></summary>
          
          - <details><summary><span style="font-family: monospace">dim_env</span></summary>
            
            - <details><summary></summary>
              
              - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
              - ```
                (((id 15) (label ()))
                 (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                  (lub ())))
                ```
                
              - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
              - ```
                (((id 21) (label ()))
                 (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                ```
                
              - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
              - ```
                (((id 27) (label ()))
                 (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                  (lub ())))
                ```
                
              - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
              - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
              - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
              - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 83) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 85) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              </details>
            </details>
          - <details><summary><span style="font-family: monospace">row_env</span></summary>
            
            - <details><summary></summary>
              
              - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
              - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
              - ```
                ((Row_var 4)
                 (Solved
                  ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                ```
                
              - ```
                ((Row_var 5)
                 (Bounds (cur ((Row_var 40))) (subr ())
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                ```
                
              - ```
                ((Row_var 6)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                ```
                
              - ```
                ((Row_var 7)
                 (Bounds (cur ((Row_var 61))) (subr ())
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                ```
                
              - ```
                ((Row_var 8)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 84))) (id ((sh_id 12) (kind Input))))))
                ```
                
              - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
              - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
              - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
              - ```
                ((Row_var 12)
                 (Solved
                  ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                   (id ((sh_id 17) (kind Output))))))
                ```
                
              - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
              - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
              - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
              - ```
                ((Row_var 18)
                 (Solved
                  ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                   (id ((sh_id 19) (kind Output))))))
                ```
                
              - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
              - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
              - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
              - ```
                ((Row_var 24)
                 (Solved
                  ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                   (id ((sh_id 20) (kind Output))))))
                ```
                
              - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
              - ```
                ((Row_var 28)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 21) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 29)
                 (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                ```
                
              - ```
                ((Row_var 30)
                 (Solved
                  ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 21) (kind Output))))))
                ```
                
              - ```
                ((Row_var 33)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 22) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 34)
                 (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                ```
                
              - ```
                ((Row_var 35)
                 (Solved
                  ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 22) (kind Output))))))
                ```
                
              - ```
                ((Row_var 38)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                ```
                
              - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
              - ```
                ((Row_var 40)
                 (Bounds (cur ()) (subr ((Row_var 5)))
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                ```
                
              - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
              - ```
                ((Row_var 45)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 46)
                 (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                ```
                
              - ```
                ((Row_var 47)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                ```
                
              - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
              - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
              - ```
                ((Row_var 52)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                ```
                
              - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
              - ```
                ((Row_var 54)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                ```
                
              - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
              - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
              - ```
                ((Row_var 59)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                ```
                
              - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
              - ```
                ((Row_var 61)
                 (Bounds (cur ()) (subr ((Row_var 7)))
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                ```
                
              - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
              - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
              - ```
                ((Row_var 66)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 67)
                 (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                ```
                
              - ```
                ((Row_var 68)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                ```
                
              - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
              - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
              - ```
                ((Row_var 73)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                ```
                
              - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
              - ```
                ((Row_var 75)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                ```
                
              - `((Row_var 77) (Bounds (cur ((Row_var 86))) (subr ((Row_var 70))) (lub ())))`
              - `((Row_var 79) (Bounds (cur ((Row_var 84))) (subr ((Row_var 72))) (lub ())))`
              - ```
                ((Row_var 80)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 86))) (id ((sh_id 35) (kind Batch))))))
                ```
                
              - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
              - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
              - `((Row_var 84) (Bounds (cur ()) (subr ((Row_var 79))) (lub ())))`
              - `((Row_var 86) (Bounds (cur ()) (subr ((Row_var 77))) (lub ())))`
              </details>
            </details>
          </details>
        </details>
      - <details><summary>ineqs =</summary>
        
        - ```
          (Dim_ineq (cur (Var ((id 83) (label ()))))
           (subr (Dim (d 16) (label ()) (proj_id ()))))
          ```
          
        - ```
          (Row_ineq
           (cur
            ((dims ((Var ((id 83) (label ()))))) (bcast (Row_var (Row_var 84)))
             (id ((sh_id 12) (kind Input)))))
           (subr
            ((dims ((Dim (d 16) (label ()) (proj_id ()))))
             (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
          ```
          
        - ```
          (Row_eq
           (r1
            ((dims ()) (bcast (Row_var (Row_var 8))) (id ((sh_id 12) (kind Input)))))
           (r2
            ((dims ((Var ((id 83) (label ()))))) (bcast (Row_var (Row_var 84)))
             (id ((sh_id 12) (kind Input))))))
          ```
          
        - ```
          (Dim_ineq (cur (Var ((id 85) (label ()))))
           (subr (Dim (d 64) (label ()) (proj_id ()))))
          ```
          
        - ```
          (Row_ineq
           (cur
            ((dims ((Var ((id 85) (label ()))))) (bcast (Row_var (Row_var 86)))
             (id ((sh_id 35) (kind Batch)))))
           (subr
            ((dims ((Dim (d 64) (label ()) (proj_id ()))))
             (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
          ```
          
        - ```
          (Row_eq
           (r1
            ((dims ()) (bcast (Row_var (Row_var 80))) (id ((sh_id 35) (kind Batch)))))
           (r2
            ((dims ((Var ((id 85) (label ()))))) (bcast (Row_var (Row_var 86)))
             (id ((sh_id 35) (kind Batch))))))
          ```
          
        </details>
      - <details><summary>env =</summary>
        
        - <details><summary><span style="font-family: monospace">dim_env</span></summary>
          
          - <details><summary></summary>
            
            - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
            - ```
              (((id 15) (label ()))
               (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                (lub ())))
              ```
              
            - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
            - ```
              (((id 21) (label ()))
               (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
              ```
              
            - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
            - ```
              (((id 27) (label ()))
               (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                (lub ())))
              ```
              
            - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
            - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
            - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
            - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
            - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
            </details>
          </details>
        - <details><summary><span style="font-family: monospace">row_env</span></summary>
          
          - <details><summary></summary>
            
            - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
            - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
            - ```
              ((Row_var 4)
               (Solved
                ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
              ```
              
            - ```
              ((Row_var 5)
               (Bounds (cur ((Row_var 40))) (subr ())
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
              ```
              
            - ```
              ((Row_var 6)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
              ```
              
            - ```
              ((Row_var 7)
               (Bounds (cur ((Row_var 61))) (subr ())
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
              ```
              
            - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
            - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
            - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
            - ```
              ((Row_var 12)
               (Solved
                ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                 (id ((sh_id 17) (kind Output))))))
              ```
              
            - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
            - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
            - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
            - ```
              ((Row_var 18)
               (Solved
                ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                 (id ((sh_id 19) (kind Output))))))
              ```
              
            - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
            - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
            - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
            - ```
              ((Row_var 24)
               (Solved
                ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                 (id ((sh_id 20) (kind Output))))))
              ```
              
            - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
            - ```
              ((Row_var 28)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 21) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 29)
               (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
              ```
              
            - ```
              ((Row_var 30)
               (Solved
                ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 21) (kind Output))))))
              ```
              
            - ```
              ((Row_var 33)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 22) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 34)
               (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
              ```
              
            - ```
              ((Row_var 35)
               (Solved
                ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                 (id ((sh_id 22) (kind Output))))))
              ```
              
            - ```
              ((Row_var 38)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
              ```
              
            - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
            - ```
              ((Row_var 40)
               (Bounds (cur ()) (subr ((Row_var 5)))
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
              ```
              
            - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
            - ```
              ((Row_var 45)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 46)
               (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
              ```
              
            - ```
              ((Row_var 47)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
              ```
              
            - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
            - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
            - ```
              ((Row_var 52)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
              ```
              
            - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
            - ```
              ((Row_var 54)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
              ```
              
            - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
            - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
            - ```
              ((Row_var 59)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
              ```
              
            - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
            - ```
              ((Row_var 61)
               (Bounds (cur ()) (subr ((Row_var 7)))
                (lub
                 (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
              ```
              
            - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
            - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
            - ```
              ((Row_var 66)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
              ```
              
            - ```
              ((Row_var 67)
               (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
              ```
              
            - ```
              ((Row_var 68)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
              ```
              
            - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
            - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
            - ```
              ((Row_var 73)
               (Solved
                ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
              ```
              
            - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
            - ```
              ((Row_var 75)
               (Solved
                ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                 (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
              ```
              
            - `((Row_var 77) (Bounds (cur ()) (subr ((Row_var 70))) (lub ())))`
            - `((Row_var 79) (Bounds (cur ()) (subr ((Row_var 72))) (lub ())))`
            - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
            - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
            </details>
          </details>
        </details>
      - <details><summary>solve_dim_ineq =</summary>
        
        - ["lib/row.ml":405:30-511:102](./lib/row.ml#L405)
        - <details><summary><returns></summary>
          
          - ```
            ((Dim_eq (d1 (Var ((id 83) (label ()))))
              (d2 (Dim (d 16) (label ()) (proj_id ())))))
            ```
            
          - <details><summary></summary>
            
            - <details><summary><span style="font-family: monospace">dim_env</span></summary>
              
              - <details><summary></summary>
                
                - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
                - ```
                  (((id 15) (label ()))
                   (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                    (lub ())))
                  ```
                  
                - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
                - ```
                  (((id 21) (label ()))
                   (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                  ```
                  
                - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
                - ```
                  (((id 27) (label ()))
                   (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                    (lub ())))
                  ```
                  
                - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
                - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                </details>
              </details>
            - <details><summary><span style="font-family: monospace">row_env</span></summary>
              
              - <details><summary></summary>
                
                - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 4)
                   (Solved
                    ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 5)
                   (Bounds (cur ((Row_var 40))) (subr ())
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                  ```
                  
                - ```
                  ((Row_var 6)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 7)
                   (Bounds (cur ((Row_var 61))) (subr ())
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                  ```
                  
                - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
                - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
                - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 12)
                   (Solved
                    ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                     (id ((sh_id 17) (kind Output))))))
                  ```
                  
                - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
                - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
                - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
                - ```
                  ((Row_var 18)
                   (Solved
                    ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                     (id ((sh_id 19) (kind Output))))))
                  ```
                  
                - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
                - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
                - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
                - ```
                  ((Row_var 24)
                   (Solved
                    ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                     (id ((sh_id 20) (kind Output))))))
                  ```
                  
                - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
                - ```
                  ((Row_var 28)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 21) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 29)
                   (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 30)
                   (Solved
                    ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 21) (kind Output))))))
                  ```
                  
                - ```
                  ((Row_var 33)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 22) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 34)
                   (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 35)
                   (Solved
                    ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 22) (kind Output))))))
                  ```
                  
                - ```
                  ((Row_var 38)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                  ```
                  
                - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 40)
                   (Bounds (cur ()) (subr ((Row_var 5)))
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                  ```
                  
                - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 45)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 46)
                   (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                  ```
                  
                - ```
                  ((Row_var 47)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                  ```
                  
                - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
                - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 52)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                  ```
                  
                - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
                - ```
                  ((Row_var 54)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                  ```
                  
                - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
                - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
                - ```
                  ((Row_var 59)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                  ```
                  
                - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
                - ```
                  ((Row_var 61)
                   (Bounds (cur ()) (subr ((Row_var 7)))
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                  ```
                  
                - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
                - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
                - ```
                  ((Row_var 66)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 67)
                   (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                  ```
                  
                - ```
                  ((Row_var 68)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                  ```
                  
                - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
                - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 73)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                  ```
                  
                - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
                - ```
                  ((Row_var 75)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                  ```
                  
                - `((Row_var 77) (Bounds (cur ()) (subr ((Row_var 70))) (lub ())))`
                - `((Row_var 79) (Bounds (cur ()) (subr ((Row_var 72))) (lub ())))`
                - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
                - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
                </details>
              </details>
            </details>
          </details>
        - `finish = false`
        - `cur = (Var ((id 83) (label ())))`
        - `subr = (Dim (d 16) (label ()) (proj_id ()))`
        - <details><summary>env =</summary>
          
          - <details><summary><span style="font-family: monospace">dim_env</span></summary>
            
            - <details><summary></summary>
              
              - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
              - ```
                (((id 15) (label ()))
                 (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                  (lub ())))
                ```
                
              - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
              - ```
                (((id 21) (label ()))
                 (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                ```
                
              - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
              - ```
                (((id 27) (label ()))
                 (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                  (lub ())))
                ```
                
              - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
              - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
              - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
              - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              </details>
            </details>
          - <details><summary><span style="font-family: monospace">row_env</span></summary>
            
            - <details><summary></summary>
              
              - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
              - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
              - ```
                ((Row_var 4)
                 (Solved
                  ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                ```
                
              - ```
                ((Row_var 5)
                 (Bounds (cur ((Row_var 40))) (subr ())
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                ```
                
              - ```
                ((Row_var 6)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                ```
                
              - ```
                ((Row_var 7)
                 (Bounds (cur ((Row_var 61))) (subr ())
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                ```
                
              - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
              - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
              - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
              - ```
                ((Row_var 12)
                 (Solved
                  ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                   (id ((sh_id 17) (kind Output))))))
                ```
                
              - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
              - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
              - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
              - ```
                ((Row_var 18)
                 (Solved
                  ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                   (id ((sh_id 19) (kind Output))))))
                ```
                
              - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
              - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
              - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
              - ```
                ((Row_var 24)
                 (Solved
                  ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                   (id ((sh_id 20) (kind Output))))))
                ```
                
              - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
              - ```
                ((Row_var 28)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 21) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 29)
                 (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                ```
                
              - ```
                ((Row_var 30)
                 (Solved
                  ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 21) (kind Output))))))
                ```
                
              - ```
                ((Row_var 33)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 22) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 34)
                 (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                ```
                
              - ```
                ((Row_var 35)
                 (Solved
                  ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 22) (kind Output))))))
                ```
                
              - ```
                ((Row_var 38)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                ```
                
              - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
              - ```
                ((Row_var 40)
                 (Bounds (cur ()) (subr ((Row_var 5)))
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                ```
                
              - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
              - ```
                ((Row_var 45)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 46)
                 (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                ```
                
              - ```
                ((Row_var 47)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                ```
                
              - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
              - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
              - ```
                ((Row_var 52)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                ```
                
              - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
              - ```
                ((Row_var 54)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                ```
                
              - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
              - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
              - ```
                ((Row_var 59)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                ```
                
              - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
              - ```
                ((Row_var 61)
                 (Bounds (cur ()) (subr ((Row_var 7)))
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                ```
                
              - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
              - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
              - ```
                ((Row_var 66)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 67)
                 (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                ```
                
              - ```
                ((Row_var 68)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                ```
                
              - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
              - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
              - ```
                ((Row_var 73)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                ```
                
              - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
              - ```
                ((Row_var 75)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                ```
                
              - `((Row_var 77) (Bounds (cur ()) (subr ((Row_var 70))) (lub ())))`
              - `((Row_var 79) (Bounds (cur ()) (subr ((Row_var 72))) (lub ())))`
              - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
              - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
              </details>
            </details>
          </details>
        - <details><summary><match -- branch 7></summary>
          
          - ["lib/row.ml":509:4](./lib/row.ml#L509)
          </details>
        </details>
      - <details><summary>solve_row_ineq =</summary>
        
        - ["lib/row.ml":515:30-651:102](./lib/row.ml#L515)
        - <details><summary><returns></summary>
          
          - ```
            ((Dim_ineq (cur (Var ((id 83) (label ()))))
              (subr (Dim (d 16) (label ()) (proj_id ())))))
            ```
            
          - <details><summary></summary>
            
            - <details><summary><span style="font-family: monospace">dim_env</span></summary>
              
              - <details><summary></summary>
                
                - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
                - ```
                  (((id 15) (label ()))
                   (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                    (lub ())))
                  ```
                  
                - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
                - ```
                  (((id 21) (label ()))
                   (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                  ```
                  
                - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
                - ```
                  (((id 27) (label ()))
                   (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                    (lub ())))
                  ```
                  
                - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
                - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                </details>
              </details>
            - <details><summary><span style="font-family: monospace">row_env</span></summary>
              
              - <details><summary></summary>
                
                - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 4)
                   (Solved
                    ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 5)
                   (Bounds (cur ((Row_var 40))) (subr ())
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                  ```
                  
                - ```
                  ((Row_var 6)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 7)
                   (Bounds (cur ((Row_var 61))) (subr ())
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                  ```
                  
                - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
                - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
                - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 12)
                   (Solved
                    ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                     (id ((sh_id 17) (kind Output))))))
                  ```
                  
                - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
                - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
                - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
                - ```
                  ((Row_var 18)
                   (Solved
                    ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                     (id ((sh_id 19) (kind Output))))))
                  ```
                  
                - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
                - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
                - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
                - ```
                  ((Row_var 24)
                   (Solved
                    ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                     (id ((sh_id 20) (kind Output))))))
                  ```
                  
                - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
                - ```
                  ((Row_var 28)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 21) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 29)
                   (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 30)
                   (Solved
                    ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 21) (kind Output))))))
                  ```
                  
                - ```
                  ((Row_var 33)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 22) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 34)
                   (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 35)
                   (Solved
                    ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 22) (kind Output))))))
                  ```
                  
                - ```
                  ((Row_var 38)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                  ```
                  
                - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 40)
                   (Bounds (cur ()) (subr ((Row_var 5)))
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                  ```
                  
                - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 45)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 46)
                   (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                  ```
                  
                - ```
                  ((Row_var 47)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                  ```
                  
                - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
                - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 52)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                  ```
                  
                - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
                - ```
                  ((Row_var 54)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                  ```
                  
                - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
                - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
                - ```
                  ((Row_var 59)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                  ```
                  
                - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
                - ```
                  ((Row_var 61)
                   (Bounds (cur ()) (subr ((Row_var 7)))
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                  ```
                  
                - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
                - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
                - ```
                  ((Row_var 66)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 67)
                   (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                  ```
                  
                - ```
                  ((Row_var 68)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                  ```
                  
                - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
                - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 73)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                  ```
                  
                - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
                - ```
                  ((Row_var 75)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                  ```
                  
                - `((Row_var 77) (Bounds (cur ()) (subr ((Row_var 70))) (lub ())))`
                - `((Row_var 79) (Bounds (cur ((Row_var 84))) (subr ((Row_var 72))) (lub ())))`
                - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
                - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
                - `((Row_var 84) (Bounds (cur ()) (subr ((Row_var 79))) (lub ())))`
                </details>
              </details>
            </details>
          </details>
        - `finish = false`
        - <details><summary>cur =</summary>
          
          - `(dims ((Var ((id 83) (label ())))))`
          - `(bcast (Row_var (Row_var 84)))`
          - `(id ((sh_id 12) (kind Input)))`
          </details>
        - <details><summary>subr =</summary>
          
          - `(dims ((Dim (d 16) (label ()) (proj_id ()))))`
          - `(bcast (Row_var (Row_var 79)))`
          - `(id ((sh_id 33) (kind Output)))`
          </details>
        - <details><summary>env =</summary>
          
          - <details><summary><span style="font-family: monospace">dim_env</span></summary>
            
            - <details><summary></summary>
              
              - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
              - ```
                (((id 15) (label ()))
                 (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                  (lub ())))
                ```
                
              - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
              - ```
                (((id 21) (label ()))
                 (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                ```
                
              - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
              - ```
                (((id 27) (label ()))
                 (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                  (lub ())))
                ```
                
              - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
              - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
              - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
              - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              </details>
            </details>
          - <details><summary><span style="font-family: monospace">row_env</span></summary>
            
            - <details><summary></summary>
              
              - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
              - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
              - ```
                ((Row_var 4)
                 (Solved
                  ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                ```
                
              - ```
                ((Row_var 5)
                 (Bounds (cur ((Row_var 40))) (subr ())
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                ```
                
              - ```
                ((Row_var 6)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                ```
                
              - ```
                ((Row_var 7)
                 (Bounds (cur ((Row_var 61))) (subr ())
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                ```
                
              - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
              - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
              - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
              - ```
                ((Row_var 12)
                 (Solved
                  ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                   (id ((sh_id 17) (kind Output))))))
                ```
                
              - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
              - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
              - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
              - ```
                ((Row_var 18)
                 (Solved
                  ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                   (id ((sh_id 19) (kind Output))))))
                ```
                
              - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
              - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
              - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
              - ```
                ((Row_var 24)
                 (Solved
                  ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                   (id ((sh_id 20) (kind Output))))))
                ```
                
              - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
              - ```
                ((Row_var 28)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 21) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 29)
                 (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                ```
                
              - ```
                ((Row_var 30)
                 (Solved
                  ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 21) (kind Output))))))
                ```
                
              - ```
                ((Row_var 33)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 22) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 34)
                 (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                ```
                
              - ```
                ((Row_var 35)
                 (Solved
                  ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 22) (kind Output))))))
                ```
                
              - ```
                ((Row_var 38)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                ```
                
              - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
              - ```
                ((Row_var 40)
                 (Bounds (cur ()) (subr ((Row_var 5)))
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                ```
                
              - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
              - ```
                ((Row_var 45)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 46)
                 (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                ```
                
              - ```
                ((Row_var 47)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                ```
                
              - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
              - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
              - ```
                ((Row_var 52)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                ```
                
              - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
              - ```
                ((Row_var 54)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                ```
                
              - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
              - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
              - ```
                ((Row_var 59)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                ```
                
              - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
              - ```
                ((Row_var 61)
                 (Bounds (cur ()) (subr ((Row_var 7)))
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                ```
                
              - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
              - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
              - ```
                ((Row_var 66)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 67)
                 (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                ```
                
              - ```
                ((Row_var 68)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                ```
                
              - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
              - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
              - ```
                ((Row_var 73)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                ```
                
              - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
              - ```
                ((Row_var 75)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                ```
                
              - `((Row_var 77) (Bounds (cur ()) (subr ((Row_var 70))) (lub ())))`
              - `((Row_var 79) (Bounds (cur ()) (subr ((Row_var 72))) (lub ())))`
              - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
              - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
              </details>
            </details>
          </details>
        - <details><summary>__fun</summary>
          
          - ["lib/row.ml":524:9-524:49](./lib/row.ml#L524)
          </details>
        - <details><summary><match -- branch 2></summary>
          
          - ["lib/row.ml":533:4](./lib/row.ml#L533)
          - <details><summary><match -- branch 7></summary>
            
            - ["lib/row.ml":564:8](./lib/row.ml#L564)
            - <details><summary>__fun</summary>
              
              - ["lib/row.ml":570:48-571:90](./lib/row.ml#L570)
              - <details><summary>nonredundant</summary>
                
                - ["lib/row.ml":517:19-518:108](./lib/row.ml#L517)
                </details>
              </details>
            </details>
          </details>
        </details>
      - <details><summary>unify_row =</summary>
        
        - ["lib/row.ml":330:29-403:103](./lib/row.ml#L330)
        - <details><summary><returns></summary>
          
          - `()`
          - <details><summary></summary>
            
            - <details><summary><span style="font-family: monospace">dim_env</span></summary>
              
              - <details><summary></summary>
                
                - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
                - ```
                  (((id 15) (label ()))
                   (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                    (lub ())))
                  ```
                  
                - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
                - ```
                  (((id 21) (label ()))
                   (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                  ```
                  
                - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
                - ```
                  (((id 27) (label ()))
                   (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                    (lub ())))
                  ```
                  
                - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
                - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                </details>
              </details>
            - <details><summary><span style="font-family: monospace">row_env</span></summary>
              
              - <details><summary></summary>
                
                - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 4)
                   (Solved
                    ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 5)
                   (Bounds (cur ((Row_var 40))) (subr ())
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                  ```
                  
                - ```
                  ((Row_var 6)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 7)
                   (Bounds (cur ((Row_var 61))) (subr ())
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                  ```
                  
                - ```
                  ((Row_var 8)
                   (Solved
                    ((dims ((Var ((id 83) (label ()))))) (bcast (Row_var (Row_var 84)))
                     (id ((sh_id 12) (kind Input))))))
                  ```
                  
                - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
                - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
                - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 12)
                   (Solved
                    ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                     (id ((sh_id 17) (kind Output))))))
                  ```
                  
                - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
                - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
                - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
                - ```
                  ((Row_var 18)
                   (Solved
                    ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                     (id ((sh_id 19) (kind Output))))))
                  ```
                  
                - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
                - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
                - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
                - ```
                  ((Row_var 24)
                   (Solved
                    ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                     (id ((sh_id 20) (kind Output))))))
                  ```
                  
                - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
                - ```
                  ((Row_var 28)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 21) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 29)
                   (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 30)
                   (Solved
                    ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 21) (kind Output))))))
                  ```
                  
                - ```
                  ((Row_var 33)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 22) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 34)
                   (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 35)
                   (Solved
                    ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 22) (kind Output))))))
                  ```
                  
                - ```
                  ((Row_var 38)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                  ```
                  
                - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 40)
                   (Bounds (cur ()) (subr ((Row_var 5)))
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                  ```
                  
                - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 45)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 46)
                   (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                  ```
                  
                - ```
                  ((Row_var 47)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                  ```
                  
                - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
                - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 52)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                  ```
                  
                - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
                - ```
                  ((Row_var 54)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                  ```
                  
                - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
                - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
                - ```
                  ((Row_var 59)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                  ```
                  
                - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
                - ```
                  ((Row_var 61)
                   (Bounds (cur ()) (subr ((Row_var 7)))
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                  ```
                  
                - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
                - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
                - ```
                  ((Row_var 66)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 67)
                   (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                  ```
                  
                - ```
                  ((Row_var 68)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                  ```
                  
                - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
                - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 73)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                  ```
                  
                - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
                - ```
                  ((Row_var 75)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                  ```
                  
                - `((Row_var 77) (Bounds (cur ()) (subr ((Row_var 70))) (lub ())))`
                - `((Row_var 79) (Bounds (cur ((Row_var 84))) (subr ((Row_var 72))) (lub ())))`
                - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
                - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
                - `((Row_var 84) (Bounds (cur ()) (subr ((Row_var 79))) (lub ())))`
                </details>
              </details>
            </details>
          </details>
        - <details><summary>eq =</summary>
          
          - `((dims ()) (bcast (Row_var (Row_var 8))) (id ((sh_id 12) (kind Input))))`
          - ```
            ((dims ((Var ((id 83) (label ()))))) (bcast (Row_var (Row_var 84)))
             (id ((sh_id 12) (kind Input))))
            ```
            
          </details>
        - <details><summary>env =</summary>
          
          - <details><summary><span style="font-family: monospace">dim_env</span></summary>
            
            - <details><summary></summary>
              
              - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
              - ```
                (((id 15) (label ()))
                 (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                  (lub ())))
                ```
                
              - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
              - ```
                (((id 21) (label ()))
                 (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                ```
                
              - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
              - ```
                (((id 27) (label ()))
                 (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                  (lub ())))
                ```
                
              - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
              - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
              - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
              - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              </details>
            </details>
          - <details><summary><span style="font-family: monospace">row_env</span></summary>
            
            - <details><summary></summary>
              
              - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
              - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
              - ```
                ((Row_var 4)
                 (Solved
                  ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                ```
                
              - ```
                ((Row_var 5)
                 (Bounds (cur ((Row_var 40))) (subr ())
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                ```
                
              - ```
                ((Row_var 6)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                ```
                
              - ```
                ((Row_var 7)
                 (Bounds (cur ((Row_var 61))) (subr ())
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                ```
                
              - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
              - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
              - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
              - ```
                ((Row_var 12)
                 (Solved
                  ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                   (id ((sh_id 17) (kind Output))))))
                ```
                
              - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
              - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
              - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
              - ```
                ((Row_var 18)
                 (Solved
                  ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                   (id ((sh_id 19) (kind Output))))))
                ```
                
              - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
              - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
              - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
              - ```
                ((Row_var 24)
                 (Solved
                  ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                   (id ((sh_id 20) (kind Output))))))
                ```
                
              - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
              - ```
                ((Row_var 28)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 21) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 29)
                 (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                ```
                
              - ```
                ((Row_var 30)
                 (Solved
                  ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 21) (kind Output))))))
                ```
                
              - ```
                ((Row_var 33)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 22) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 34)
                 (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                ```
                
              - ```
                ((Row_var 35)
                 (Solved
                  ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 22) (kind Output))))))
                ```
                
              - ```
                ((Row_var 38)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                ```
                
              - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
              - ```
                ((Row_var 40)
                 (Bounds (cur ()) (subr ((Row_var 5)))
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                ```
                
              - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
              - ```
                ((Row_var 45)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 46)
                 (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                ```
                
              - ```
                ((Row_var 47)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                ```
                
              - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
              - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
              - ```
                ((Row_var 52)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                ```
                
              - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
              - ```
                ((Row_var 54)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                ```
                
              - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
              - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
              - ```
                ((Row_var 59)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                ```
                
              - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
              - ```
                ((Row_var 61)
                 (Bounds (cur ()) (subr ((Row_var 7)))
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                ```
                
              - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
              - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
              - ```
                ((Row_var 66)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 67)
                 (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                ```
                
              - ```
                ((Row_var 68)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                ```
                
              - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
              - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
              - ```
                ((Row_var 73)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                ```
                
              - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
              - ```
                ((Row_var 75)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                ```
                
              - `((Row_var 77) (Bounds (cur ()) (subr ((Row_var 70))) (lub ())))`
              - `((Row_var 79) (Bounds (cur ((Row_var 84))) (subr ((Row_var 72))) (lub ())))`
              - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
              - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
              - `((Row_var 84) (Bounds (cur ()) (subr ((Row_var 79))) (lub ())))`
              </details>
            </details>
          </details>
        - <details><summary>r1 =</summary>
          
          - ["lib/row.ml":346:6](./lib/row.ml#L346)
          - <details><summary><returns></summary>
            
            - `(dims ())`
            - `(bcast (Row_var (Row_var 8)))`
            - `(id ((sh_id 12) (kind Input)))`
            </details>
          </details>
        - <details><summary>r2 =</summary>
          
          - ["lib/row.ml":346:43](./lib/row.ml#L346)
          - <details><summary><returns></summary>
            
            - `(dims ((Var ((id 83) (label ())))))`
            - `(bcast (Row_var (Row_var 84)))`
            - `(id ((sh_id 12) (kind Input)))`
            </details>
          </details>
        - <details><summary><span style="font-family: monospace">r1_len = 0</span></summary>
          
          - ["lib/row.ml":356:10](./lib/row.ml#L356)
          </details>
        - <details><summary><span style="font-family: monospace">r2_len = 1</span></summary>
          
          - ["lib/row.ml":356:49](./lib/row.ml#L356)
          </details>
        - <details><summary>value =</summary>
          
          - ["lib/row.ml":368:12](./lib/row.ml#L368)
          - <details><summary><returns></summary>
            
            - `(dims ((Var ((id 83) (label ())))))`
            - `(bcast (Row_var (Row_var 84)))`
            - `(id ((sh_id 12) (kind Input)))`
            </details>
          </details>
        - <details><summary>ineqs</summary>
          
          - ["lib/row.ml":371:12](./lib/row.ml#L371)
          </details>
        - <details><summary>env =</summary>
          
          - ["lib/row.ml":380:16](./lib/row.ml#L380)
          - <details><summary><returns></summary>
            
            - <details><summary><span style="font-family: monospace">dim_env</span></summary>
              
              - <details><summary></summary>
                
                - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
                - ```
                  (((id 15) (label ()))
                   (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                    (lub ())))
                  ```
                  
                - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
                - ```
                  (((id 21) (label ()))
                   (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                  ```
                  
                - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
                - ```
                  (((id 27) (label ()))
                   (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                    (lub ())))
                  ```
                  
                - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
                - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                </details>
              </details>
            - <details><summary><span style="font-family: monospace">row_env</span></summary>
              
              - <details><summary></summary>
                
                - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 4)
                   (Solved
                    ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 5)
                   (Bounds (cur ((Row_var 40))) (subr ())
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                  ```
                  
                - ```
                  ((Row_var 6)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 7)
                   (Bounds (cur ((Row_var 61))) (subr ())
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                  ```
                  
                - ```
                  ((Row_var 8)
                   (Solved
                    ((dims ((Var ((id 83) (label ()))))) (bcast (Row_var (Row_var 84)))
                     (id ((sh_id 12) (kind Input))))))
                  ```
                  
                - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
                - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
                - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 12)
                   (Solved
                    ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                     (id ((sh_id 17) (kind Output))))))
                  ```
                  
                - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
                - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
                - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
                - ```
                  ((Row_var 18)
                   (Solved
                    ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                     (id ((sh_id 19) (kind Output))))))
                  ```
                  
                - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
                - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
                - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
                - ```
                  ((Row_var 24)
                   (Solved
                    ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                     (id ((sh_id 20) (kind Output))))))
                  ```
                  
                - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
                - ```
                  ((Row_var 28)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 21) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 29)
                   (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 30)
                   (Solved
                    ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 21) (kind Output))))))
                  ```
                  
                - ```
                  ((Row_var 33)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 22) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 34)
                   (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 35)
                   (Solved
                    ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 22) (kind Output))))))
                  ```
                  
                - ```
                  ((Row_var 38)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                  ```
                  
                - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 40)
                   (Bounds (cur ()) (subr ((Row_var 5)))
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                  ```
                  
                - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 45)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 46)
                   (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                  ```
                  
                - ```
                  ((Row_var 47)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                  ```
                  
                - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
                - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 52)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                  ```
                  
                - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
                - ```
                  ((Row_var 54)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                  ```
                  
                - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
                - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
                - ```
                  ((Row_var 59)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                  ```
                  
                - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
                - ```
                  ((Row_var 61)
                   (Bounds (cur ()) (subr ((Row_var 7)))
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                  ```
                  
                - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
                - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
                - ```
                  ((Row_var 66)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 67)
                   (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                  ```
                  
                - ```
                  ((Row_var 68)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                  ```
                  
                - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
                - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 73)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                  ```
                  
                - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
                - ```
                  ((Row_var 75)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                  ```
                  
                - `((Row_var 77) (Bounds (cur ()) (subr ((Row_var 70))) (lub ())))`
                - `((Row_var 79) (Bounds (cur ((Row_var 84))) (subr ((Row_var 72))) (lub ())))`
                - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
                - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
                - `((Row_var 84) (Bounds (cur ()) (subr ((Row_var 79))) (lub ())))`
                </details>
              </details>
            </details>
          </details>
        </details>
      - <details><summary>solve_dim_ineq =</summary>
        
        - ["lib/row.ml":405:30-511:102](./lib/row.ml#L405)
        - <details><summary><returns></summary>
          
          - ```
            ((Dim_eq (d1 (Var ((id 85) (label ()))))
              (d2 (Dim (d 64) (label ()) (proj_id ())))))
            ```
            
          - <details><summary></summary>
            
            - <details><summary><span style="font-family: monospace">dim_env</span></summary>
              
              - <details><summary></summary>
                
                - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
                - ```
                  (((id 15) (label ()))
                   (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                    (lub ())))
                  ```
                  
                - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
                - ```
                  (((id 21) (label ()))
                   (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                  ```
                  
                - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
                - ```
                  (((id 27) (label ()))
                   (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                    (lub ())))
                  ```
                  
                - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
                - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                </details>
              </details>
            - <details><summary><span style="font-family: monospace">row_env</span></summary>
              
              - <details><summary></summary>
                
                - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 4)
                   (Solved
                    ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 5)
                   (Bounds (cur ((Row_var 40))) (subr ())
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                  ```
                  
                - ```
                  ((Row_var 6)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 7)
                   (Bounds (cur ((Row_var 61))) (subr ())
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                  ```
                  
                - ```
                  ((Row_var 8)
                   (Solved
                    ((dims ((Var ((id 83) (label ()))))) (bcast (Row_var (Row_var 84)))
                     (id ((sh_id 12) (kind Input))))))
                  ```
                  
                - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
                - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
                - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 12)
                   (Solved
                    ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                     (id ((sh_id 17) (kind Output))))))
                  ```
                  
                - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
                - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
                - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
                - ```
                  ((Row_var 18)
                   (Solved
                    ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                     (id ((sh_id 19) (kind Output))))))
                  ```
                  
                - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
                - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
                - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
                - ```
                  ((Row_var 24)
                   (Solved
                    ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                     (id ((sh_id 20) (kind Output))))))
                  ```
                  
                - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
                - ```
                  ((Row_var 28)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 21) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 29)
                   (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 30)
                   (Solved
                    ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 21) (kind Output))))))
                  ```
                  
                - ```
                  ((Row_var 33)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 22) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 34)
                   (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 35)
                   (Solved
                    ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 22) (kind Output))))))
                  ```
                  
                - ```
                  ((Row_var 38)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                  ```
                  
                - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 40)
                   (Bounds (cur ()) (subr ((Row_var 5)))
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                  ```
                  
                - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 45)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 46)
                   (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                  ```
                  
                - ```
                  ((Row_var 47)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                  ```
                  
                - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
                - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 52)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                  ```
                  
                - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
                - ```
                  ((Row_var 54)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                  ```
                  
                - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
                - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
                - ```
                  ((Row_var 59)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                  ```
                  
                - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
                - ```
                  ((Row_var 61)
                   (Bounds (cur ()) (subr ((Row_var 7)))
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                  ```
                  
                - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
                - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
                - ```
                  ((Row_var 66)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 67)
                   (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                  ```
                  
                - ```
                  ((Row_var 68)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                  ```
                  
                - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
                - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 73)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                  ```
                  
                - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
                - ```
                  ((Row_var 75)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                  ```
                  
                - `((Row_var 77) (Bounds (cur ()) (subr ((Row_var 70))) (lub ())))`
                - `((Row_var 79) (Bounds (cur ((Row_var 84))) (subr ((Row_var 72))) (lub ())))`
                - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
                - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
                - `((Row_var 84) (Bounds (cur ()) (subr ((Row_var 79))) (lub ())))`
                </details>
              </details>
            </details>
          </details>
        - `finish = false`
        - `cur = (Var ((id 85) (label ())))`
        - `subr = (Dim (d 64) (label ()) (proj_id ()))`
        - <details><summary>env =</summary>
          
          - <details><summary><span style="font-family: monospace">dim_env</span></summary>
            
            - <details><summary></summary>
              
              - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
              - ```
                (((id 15) (label ()))
                 (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                  (lub ())))
                ```
                
              - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
              - ```
                (((id 21) (label ()))
                 (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                ```
                
              - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
              - ```
                (((id 27) (label ()))
                 (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                  (lub ())))
                ```
                
              - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
              - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
              - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
              - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              </details>
            </details>
          - <details><summary><span style="font-family: monospace">row_env</span></summary>
            
            - <details><summary></summary>
              
              - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
              - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
              - ```
                ((Row_var 4)
                 (Solved
                  ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                ```
                
              - ```
                ((Row_var 5)
                 (Bounds (cur ((Row_var 40))) (subr ())
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                ```
                
              - ```
                ((Row_var 6)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                ```
                
              - ```
                ((Row_var 7)
                 (Bounds (cur ((Row_var 61))) (subr ())
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                ```
                
              - ```
                ((Row_var 8)
                 (Solved
                  ((dims ((Var ((id 83) (label ()))))) (bcast (Row_var (Row_var 84)))
                   (id ((sh_id 12) (kind Input))))))
                ```
                
              - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
              - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
              - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
              - ```
                ((Row_var 12)
                 (Solved
                  ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                   (id ((sh_id 17) (kind Output))))))
                ```
                
              - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
              - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
              - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
              - ```
                ((Row_var 18)
                 (Solved
                  ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                   (id ((sh_id 19) (kind Output))))))
                ```
                
              - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
              - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
              - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
              - ```
                ((Row_var 24)
                 (Solved
                  ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                   (id ((sh_id 20) (kind Output))))))
                ```
                
              - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
              - ```
                ((Row_var 28)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 21) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 29)
                 (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                ```
                
              - ```
                ((Row_var 30)
                 (Solved
                  ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 21) (kind Output))))))
                ```
                
              - ```
                ((Row_var 33)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 22) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 34)
                 (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                ```
                
              - ```
                ((Row_var 35)
                 (Solved
                  ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 22) (kind Output))))))
                ```
                
              - ```
                ((Row_var 38)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                ```
                
              - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
              - ```
                ((Row_var 40)
                 (Bounds (cur ()) (subr ((Row_var 5)))
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                ```
                
              - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
              - ```
                ((Row_var 45)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 46)
                 (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                ```
                
              - ```
                ((Row_var 47)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                ```
                
              - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
              - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
              - ```
                ((Row_var 52)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                ```
                
              - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
              - ```
                ((Row_var 54)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                ```
                
              - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
              - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
              - ```
                ((Row_var 59)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                ```
                
              - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
              - ```
                ((Row_var 61)
                 (Bounds (cur ()) (subr ((Row_var 7)))
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                ```
                
              - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
              - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
              - ```
                ((Row_var 66)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 67)
                 (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                ```
                
              - ```
                ((Row_var 68)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                ```
                
              - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
              - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
              - ```
                ((Row_var 73)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                ```
                
              - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
              - ```
                ((Row_var 75)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                ```
                
              - `((Row_var 77) (Bounds (cur ()) (subr ((Row_var 70))) (lub ())))`
              - `((Row_var 79) (Bounds (cur ((Row_var 84))) (subr ((Row_var 72))) (lub ())))`
              - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
              - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
              - `((Row_var 84) (Bounds (cur ()) (subr ((Row_var 79))) (lub ())))`
              </details>
            </details>
          </details>
        - <details><summary><match -- branch 7></summary>
          
          - ["lib/row.ml":509:4](./lib/row.ml#L509)
          </details>
        </details>
      - <details><summary>solve_row_ineq =</summary>
        
        - ["lib/row.ml":515:30-651:102](./lib/row.ml#L515)
        - <details><summary><returns></summary>
          
          - ```
            ((Dim_ineq (cur (Var ((id 85) (label ()))))
              (subr (Dim (d 64) (label ()) (proj_id ())))))
            ```
            
          - <details><summary></summary>
            
            - <details><summary><span style="font-family: monospace">dim_env</span></summary>
              
              - <details><summary></summary>
                
                - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
                - ```
                  (((id 15) (label ()))
                   (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                    (lub ())))
                  ```
                  
                - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
                - ```
                  (((id 21) (label ()))
                   (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                  ```
                  
                - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
                - ```
                  (((id 27) (label ()))
                   (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                    (lub ())))
                  ```
                  
                - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
                - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                </details>
              </details>
            - <details><summary><span style="font-family: monospace">row_env</span></summary>
              
              - <details><summary></summary>
                
                - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 4)
                   (Solved
                    ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 5)
                   (Bounds (cur ((Row_var 40))) (subr ())
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                  ```
                  
                - ```
                  ((Row_var 6)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 7)
                   (Bounds (cur ((Row_var 61))) (subr ())
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                  ```
                  
                - ```
                  ((Row_var 8)
                   (Solved
                    ((dims ((Var ((id 83) (label ()))))) (bcast (Row_var (Row_var 84)))
                     (id ((sh_id 12) (kind Input))))))
                  ```
                  
                - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
                - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
                - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 12)
                   (Solved
                    ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                     (id ((sh_id 17) (kind Output))))))
                  ```
                  
                - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
                - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
                - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
                - ```
                  ((Row_var 18)
                   (Solved
                    ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                     (id ((sh_id 19) (kind Output))))))
                  ```
                  
                - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
                - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
                - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
                - ```
                  ((Row_var 24)
                   (Solved
                    ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                     (id ((sh_id 20) (kind Output))))))
                  ```
                  
                - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
                - ```
                  ((Row_var 28)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 21) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 29)
                   (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 30)
                   (Solved
                    ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 21) (kind Output))))))
                  ```
                  
                - ```
                  ((Row_var 33)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 22) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 34)
                   (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 35)
                   (Solved
                    ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 22) (kind Output))))))
                  ```
                  
                - ```
                  ((Row_var 38)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                  ```
                  
                - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 40)
                   (Bounds (cur ()) (subr ((Row_var 5)))
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                  ```
                  
                - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 45)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 46)
                   (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                  ```
                  
                - ```
                  ((Row_var 47)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                  ```
                  
                - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
                - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 52)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                  ```
                  
                - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
                - ```
                  ((Row_var 54)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                  ```
                  
                - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
                - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
                - ```
                  ((Row_var 59)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                  ```
                  
                - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
                - ```
                  ((Row_var 61)
                   (Bounds (cur ()) (subr ((Row_var 7)))
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                  ```
                  
                - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
                - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
                - ```
                  ((Row_var 66)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 67)
                   (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                  ```
                  
                - ```
                  ((Row_var 68)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                  ```
                  
                - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
                - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 73)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                  ```
                  
                - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
                - ```
                  ((Row_var 75)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                  ```
                  
                - `((Row_var 77) (Bounds (cur ((Row_var 86))) (subr ((Row_var 70))) (lub ())))`
                - `((Row_var 79) (Bounds (cur ((Row_var 84))) (subr ((Row_var 72))) (lub ())))`
                - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
                - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
                - `((Row_var 84) (Bounds (cur ()) (subr ((Row_var 79))) (lub ())))`
                - `((Row_var 86) (Bounds (cur ()) (subr ((Row_var 77))) (lub ())))`
                </details>
              </details>
            </details>
          </details>
        - `finish = false`
        - <details><summary>cur =</summary>
          
          - `(dims ((Var ((id 85) (label ())))))`
          - `(bcast (Row_var (Row_var 86)))`
          - `(id ((sh_id 35) (kind Batch)))`
          </details>
        - <details><summary>subr =</summary>
          
          - `(dims ((Dim (d 64) (label ()) (proj_id ()))))`
          - `(bcast (Row_var (Row_var 77)))`
          - `(id ((sh_id 33) (kind Batch)))`
          </details>
        - <details><summary>env =</summary>
          
          - <details><summary><span style="font-family: monospace">dim_env</span></summary>
            
            - <details><summary></summary>
              
              - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
              - ```
                (((id 15) (label ()))
                 (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                  (lub ())))
                ```
                
              - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
              - ```
                (((id 21) (label ()))
                 (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                ```
                
              - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
              - ```
                (((id 27) (label ()))
                 (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                  (lub ())))
                ```
                
              - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
              - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
              - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
              - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              </details>
            </details>
          - <details><summary><span style="font-family: monospace">row_env</span></summary>
            
            - <details><summary></summary>
              
              - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
              - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
              - ```
                ((Row_var 4)
                 (Solved
                  ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                ```
                
              - ```
                ((Row_var 5)
                 (Bounds (cur ((Row_var 40))) (subr ())
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                ```
                
              - ```
                ((Row_var 6)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                ```
                
              - ```
                ((Row_var 7)
                 (Bounds (cur ((Row_var 61))) (subr ())
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                ```
                
              - ```
                ((Row_var 8)
                 (Solved
                  ((dims ((Var ((id 83) (label ()))))) (bcast (Row_var (Row_var 84)))
                   (id ((sh_id 12) (kind Input))))))
                ```
                
              - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
              - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
              - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
              - ```
                ((Row_var 12)
                 (Solved
                  ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                   (id ((sh_id 17) (kind Output))))))
                ```
                
              - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
              - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
              - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
              - ```
                ((Row_var 18)
                 (Solved
                  ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                   (id ((sh_id 19) (kind Output))))))
                ```
                
              - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
              - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
              - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
              - ```
                ((Row_var 24)
                 (Solved
                  ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                   (id ((sh_id 20) (kind Output))))))
                ```
                
              - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
              - ```
                ((Row_var 28)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 21) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 29)
                 (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                ```
                
              - ```
                ((Row_var 30)
                 (Solved
                  ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 21) (kind Output))))))
                ```
                
              - ```
                ((Row_var 33)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 22) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 34)
                 (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                ```
                
              - ```
                ((Row_var 35)
                 (Solved
                  ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 22) (kind Output))))))
                ```
                
              - ```
                ((Row_var 38)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                ```
                
              - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
              - ```
                ((Row_var 40)
                 (Bounds (cur ()) (subr ((Row_var 5)))
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                ```
                
              - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
              - ```
                ((Row_var 45)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 46)
                 (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                ```
                
              - ```
                ((Row_var 47)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                ```
                
              - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
              - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
              - ```
                ((Row_var 52)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                ```
                
              - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
              - ```
                ((Row_var 54)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                ```
                
              - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
              - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
              - ```
                ((Row_var 59)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                ```
                
              - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
              - ```
                ((Row_var 61)
                 (Bounds (cur ()) (subr ((Row_var 7)))
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                ```
                
              - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
              - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
              - ```
                ((Row_var 66)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 67)
                 (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                ```
                
              - ```
                ((Row_var 68)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                ```
                
              - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
              - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
              - ```
                ((Row_var 73)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                ```
                
              - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
              - ```
                ((Row_var 75)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                ```
                
              - `((Row_var 77) (Bounds (cur ()) (subr ((Row_var 70))) (lub ())))`
              - `((Row_var 79) (Bounds (cur ((Row_var 84))) (subr ((Row_var 72))) (lub ())))`
              - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
              - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
              - `((Row_var 84) (Bounds (cur ()) (subr ((Row_var 79))) (lub ())))`
              </details>
            </details>
          </details>
        - <details><summary>__fun</summary>
          
          - ["lib/row.ml":524:9-524:49](./lib/row.ml#L524)
          </details>
        - <details><summary><match -- branch 2></summary>
          
          - ["lib/row.ml":533:4](./lib/row.ml#L533)
          - <details><summary><match -- branch 7></summary>
            
            - ["lib/row.ml":564:8](./lib/row.ml#L564)
            - <details><summary>__fun</summary>
              
              - ["lib/row.ml":570:48-571:90](./lib/row.ml#L570)
              - <details><summary>nonredundant</summary>
                
                - ["lib/row.ml":517:19-518:108](./lib/row.ml#L517)
                </details>
              </details>
            </details>
          </details>
        </details>
      - <details><summary>unify_row =</summary>
        
        - ["lib/row.ml":330:29-403:103](./lib/row.ml#L330)
        - <details><summary><returns></summary>
          
          - `()`
          - <details><summary></summary>
            
            - <details><summary><span style="font-family: monospace">dim_env</span></summary>
              
              - <details><summary></summary>
                
                - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
                - ```
                  (((id 15) (label ()))
                   (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                    (lub ())))
                  ```
                  
                - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
                - ```
                  (((id 21) (label ()))
                   (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                  ```
                  
                - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
                - ```
                  (((id 27) (label ()))
                   (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                    (lub ())))
                  ```
                  
                - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
                - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                </details>
              </details>
            - <details><summary><span style="font-family: monospace">row_env</span></summary>
              
              - <details><summary></summary>
                
                - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 4)
                   (Solved
                    ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 5)
                   (Bounds (cur ((Row_var 40))) (subr ())
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                  ```
                  
                - ```
                  ((Row_var 6)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 7)
                   (Bounds (cur ((Row_var 61))) (subr ())
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                  ```
                  
                - ```
                  ((Row_var 8)
                   (Solved
                    ((dims ((Var ((id 83) (label ()))))) (bcast (Row_var (Row_var 84)))
                     (id ((sh_id 12) (kind Input))))))
                  ```
                  
                - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
                - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
                - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 12)
                   (Solved
                    ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                     (id ((sh_id 17) (kind Output))))))
                  ```
                  
                - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
                - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
                - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
                - ```
                  ((Row_var 18)
                   (Solved
                    ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                     (id ((sh_id 19) (kind Output))))))
                  ```
                  
                - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
                - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
                - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
                - ```
                  ((Row_var 24)
                   (Solved
                    ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                     (id ((sh_id 20) (kind Output))))))
                  ```
                  
                - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
                - ```
                  ((Row_var 28)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 21) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 29)
                   (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 30)
                   (Solved
                    ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 21) (kind Output))))))
                  ```
                  
                - ```
                  ((Row_var 33)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 22) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 34)
                   (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 35)
                   (Solved
                    ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 22) (kind Output))))))
                  ```
                  
                - ```
                  ((Row_var 38)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                  ```
                  
                - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 40)
                   (Bounds (cur ()) (subr ((Row_var 5)))
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                  ```
                  
                - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 45)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 46)
                   (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                  ```
                  
                - ```
                  ((Row_var 47)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                  ```
                  
                - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
                - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 52)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                  ```
                  
                - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
                - ```
                  ((Row_var 54)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                  ```
                  
                - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
                - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
                - ```
                  ((Row_var 59)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                  ```
                  
                - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
                - ```
                  ((Row_var 61)
                   (Bounds (cur ()) (subr ((Row_var 7)))
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                  ```
                  
                - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
                - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
                - ```
                  ((Row_var 66)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 67)
                   (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                  ```
                  
                - ```
                  ((Row_var 68)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                  ```
                  
                - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
                - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 73)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                  ```
                  
                - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
                - ```
                  ((Row_var 75)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                  ```
                  
                - `((Row_var 77) (Bounds (cur ((Row_var 86))) (subr ((Row_var 70))) (lub ())))`
                - `((Row_var 79) (Bounds (cur ((Row_var 84))) (subr ((Row_var 72))) (lub ())))`
                - ```
                  ((Row_var 80)
                   (Solved
                    ((dims ((Var ((id 85) (label ()))))) (bcast (Row_var (Row_var 86)))
                     (id ((sh_id 35) (kind Batch))))))
                  ```
                  
                - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
                - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
                - `((Row_var 84) (Bounds (cur ()) (subr ((Row_var 79))) (lub ())))`
                - `((Row_var 86) (Bounds (cur ()) (subr ((Row_var 77))) (lub ())))`
                </details>
              </details>
            </details>
          </details>
        - <details><summary>eq =</summary>
          
          - `((dims ()) (bcast (Row_var (Row_var 80))) (id ((sh_id 35) (kind Batch))))`
          - ```
            ((dims ((Var ((id 85) (label ()))))) (bcast (Row_var (Row_var 86)))
             (id ((sh_id 35) (kind Batch))))
            ```
            
          </details>
        - <details><summary>env =</summary>
          
          - <details><summary><span style="font-family: monospace">dim_env</span></summary>
            
            - <details><summary></summary>
              
              - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
              - ```
                (((id 15) (label ()))
                 (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                  (lub ())))
                ```
                
              - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
              - ```
                (((id 21) (label ()))
                 (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                ```
                
              - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
              - ```
                (((id 27) (label ()))
                 (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                  (lub ())))
                ```
                
              - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
              - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
              - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
              - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              </details>
            </details>
          - <details><summary><span style="font-family: monospace">row_env</span></summary>
            
            - <details><summary></summary>
              
              - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
              - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
              - ```
                ((Row_var 4)
                 (Solved
                  ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                ```
                
              - ```
                ((Row_var 5)
                 (Bounds (cur ((Row_var 40))) (subr ())
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                ```
                
              - ```
                ((Row_var 6)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                ```
                
              - ```
                ((Row_var 7)
                 (Bounds (cur ((Row_var 61))) (subr ())
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                ```
                
              - ```
                ((Row_var 8)
                 (Solved
                  ((dims ((Var ((id 83) (label ()))))) (bcast (Row_var (Row_var 84)))
                   (id ((sh_id 12) (kind Input))))))
                ```
                
              - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
              - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
              - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
              - ```
                ((Row_var 12)
                 (Solved
                  ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                   (id ((sh_id 17) (kind Output))))))
                ```
                
              - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
              - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
              - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
              - ```
                ((Row_var 18)
                 (Solved
                  ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                   (id ((sh_id 19) (kind Output))))))
                ```
                
              - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
              - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
              - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
              - ```
                ((Row_var 24)
                 (Solved
                  ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                   (id ((sh_id 20) (kind Output))))))
                ```
                
              - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
              - ```
                ((Row_var 28)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 21) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 29)
                 (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                ```
                
              - ```
                ((Row_var 30)
                 (Solved
                  ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 21) (kind Output))))))
                ```
                
              - ```
                ((Row_var 33)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 22) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 34)
                 (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                ```
                
              - ```
                ((Row_var 35)
                 (Solved
                  ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 22) (kind Output))))))
                ```
                
              - ```
                ((Row_var 38)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                ```
                
              - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
              - ```
                ((Row_var 40)
                 (Bounds (cur ()) (subr ((Row_var 5)))
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                ```
                
              - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
              - ```
                ((Row_var 45)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 46)
                 (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                ```
                
              - ```
                ((Row_var 47)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                ```
                
              - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
              - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
              - ```
                ((Row_var 52)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                ```
                
              - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
              - ```
                ((Row_var 54)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                ```
                
              - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
              - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
              - ```
                ((Row_var 59)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                ```
                
              - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
              - ```
                ((Row_var 61)
                 (Bounds (cur ()) (subr ((Row_var 7)))
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                ```
                
              - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
              - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
              - ```
                ((Row_var 66)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 67)
                 (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                ```
                
              - ```
                ((Row_var 68)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                ```
                
              - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
              - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
              - ```
                ((Row_var 73)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                ```
                
              - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
              - ```
                ((Row_var 75)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                ```
                
              - `((Row_var 77) (Bounds (cur ((Row_var 86))) (subr ((Row_var 70))) (lub ())))`
              - `((Row_var 79) (Bounds (cur ((Row_var 84))) (subr ((Row_var 72))) (lub ())))`
              - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
              - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
              - `((Row_var 84) (Bounds (cur ()) (subr ((Row_var 79))) (lub ())))`
              - `((Row_var 86) (Bounds (cur ()) (subr ((Row_var 77))) (lub ())))`
              </details>
            </details>
          </details>
        - <details><summary>r1 =</summary>
          
          - ["lib/row.ml":346:6](./lib/row.ml#L346)
          - <details><summary><returns></summary>
            
            - `(dims ())`
            - `(bcast (Row_var (Row_var 80)))`
            - `(id ((sh_id 35) (kind Batch)))`
            </details>
          </details>
        - <details><summary>r2 =</summary>
          
          - ["lib/row.ml":346:43](./lib/row.ml#L346)
          - <details><summary><returns></summary>
            
            - `(dims ((Var ((id 85) (label ())))))`
            - `(bcast (Row_var (Row_var 86)))`
            - `(id ((sh_id 35) (kind Batch)))`
            </details>
          </details>
        - <details><summary><span style="font-family: monospace">r1_len = 0</span></summary>
          
          - ["lib/row.ml":356:10](./lib/row.ml#L356)
          </details>
        - <details><summary><span style="font-family: monospace">r2_len = 1</span></summary>
          
          - ["lib/row.ml":356:49](./lib/row.ml#L356)
          </details>
        - <details><summary>value =</summary>
          
          - ["lib/row.ml":368:12](./lib/row.ml#L368)
          - <details><summary><returns></summary>
            
            - `(dims ((Var ((id 85) (label ())))))`
            - `(bcast (Row_var (Row_var 86)))`
            - `(id ((sh_id 35) (kind Batch)))`
            </details>
          </details>
        - <details><summary>ineqs</summary>
          
          - ["lib/row.ml":371:12](./lib/row.ml#L371)
          </details>
        - <details><summary>env =</summary>
          
          - ["lib/row.ml":380:16](./lib/row.ml#L380)
          - <details><summary><returns></summary>
            
            - <details><summary><span style="font-family: monospace">dim_env</span></summary>
              
              - <details><summary></summary>
                
                - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
                - ```
                  (((id 15) (label ()))
                   (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                    (lub ())))
                  ```
                  
                - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
                - ```
                  (((id 21) (label ()))
                   (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                  ```
                  
                - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
                - ```
                  (((id 27) (label ()))
                   (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                    (lub ())))
                  ```
                  
                - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
                - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                </details>
              </details>
            - <details><summary><span style="font-family: monospace">row_env</span></summary>
              
              - <details><summary></summary>
                
                - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 4)
                   (Solved
                    ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 5)
                   (Bounds (cur ((Row_var 40))) (subr ())
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                  ```
                  
                - ```
                  ((Row_var 6)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 7)
                   (Bounds (cur ((Row_var 61))) (subr ())
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                  ```
                  
                - ```
                  ((Row_var 8)
                   (Solved
                    ((dims ((Var ((id 83) (label ()))))) (bcast (Row_var (Row_var 84)))
                     (id ((sh_id 12) (kind Input))))))
                  ```
                  
                - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
                - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
                - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 12)
                   (Solved
                    ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                     (id ((sh_id 17) (kind Output))))))
                  ```
                  
                - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
                - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
                - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
                - ```
                  ((Row_var 18)
                   (Solved
                    ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                     (id ((sh_id 19) (kind Output))))))
                  ```
                  
                - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
                - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
                - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
                - ```
                  ((Row_var 24)
                   (Solved
                    ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                     (id ((sh_id 20) (kind Output))))))
                  ```
                  
                - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
                - ```
                  ((Row_var 28)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 21) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 29)
                   (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 30)
                   (Solved
                    ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 21) (kind Output))))))
                  ```
                  
                - ```
                  ((Row_var 33)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 22) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 34)
                   (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 35)
                   (Solved
                    ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 22) (kind Output))))))
                  ```
                  
                - ```
                  ((Row_var 38)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                  ```
                  
                - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 40)
                   (Bounds (cur ()) (subr ((Row_var 5)))
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                  ```
                  
                - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 45)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 46)
                   (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                  ```
                  
                - ```
                  ((Row_var 47)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                  ```
                  
                - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
                - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 52)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                  ```
                  
                - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
                - ```
                  ((Row_var 54)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                  ```
                  
                - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
                - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
                - ```
                  ((Row_var 59)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                  ```
                  
                - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
                - ```
                  ((Row_var 61)
                   (Bounds (cur ()) (subr ((Row_var 7)))
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                  ```
                  
                - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
                - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
                - ```
                  ((Row_var 66)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 67)
                   (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                  ```
                  
                - ```
                  ((Row_var 68)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                  ```
                  
                - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
                - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 73)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                  ```
                  
                - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
                - ```
                  ((Row_var 75)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                  ```
                  
                - `((Row_var 77) (Bounds (cur ((Row_var 86))) (subr ((Row_var 70))) (lub ())))`
                - `((Row_var 79) (Bounds (cur ((Row_var 84))) (subr ((Row_var 72))) (lub ())))`
                - ```
                  ((Row_var 80)
                   (Solved
                    ((dims ((Var ((id 85) (label ()))))) (bcast (Row_var (Row_var 86)))
                     (id ((sh_id 35) (kind Batch))))))
                  ```
                  
                - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
                - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
                - `((Row_var 84) (Bounds (cur ()) (subr ((Row_var 79))) (lub ())))`
                - `((Row_var 86) (Bounds (cur ()) (subr ((Row_var 77))) (lub ())))`
                </details>
              </details>
            </details>
          </details>
        </details>
      - <details><summary>solve =</summary>
        
        - ["lib/row.ml":687:16-725:25](./lib/row.ml#L687)
        - <details><summary><returns></summary>
          
          - `()`
          - <details><summary></summary>
            
            - <details><summary><span style="font-family: monospace">dim_env</span></summary>
              
              - <details><summary></summary>
                
                - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
                - ```
                  (((id 15) (label ()))
                   (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                    (lub ())))
                  ```
                  
                - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
                - ```
                  (((id 21) (label ()))
                   (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                  ```
                  
                - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
                - ```
                  (((id 27) (label ()))
                   (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                    (lub ())))
                  ```
                  
                - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
                - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 83) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 85) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                </details>
              </details>
            - <details><summary><span style="font-family: monospace">row_env</span></summary>
              
              - <details><summary></summary>
                
                - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 4)
                   (Solved
                    ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 5)
                   (Bounds (cur ((Row_var 40))) (subr ())
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                  ```
                  
                - ```
                  ((Row_var 6)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 7)
                   (Bounds (cur ((Row_var 61))) (subr ())
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                  ```
                  
                - ```
                  ((Row_var 8)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 84))) (id ((sh_id 12) (kind Input))))))
                  ```
                  
                - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
                - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
                - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 12)
                   (Solved
                    ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                     (id ((sh_id 17) (kind Output))))))
                  ```
                  
                - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
                - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
                - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
                - ```
                  ((Row_var 18)
                   (Solved
                    ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                     (id ((sh_id 19) (kind Output))))))
                  ```
                  
                - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
                - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
                - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
                - ```
                  ((Row_var 24)
                   (Solved
                    ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                     (id ((sh_id 20) (kind Output))))))
                  ```
                  
                - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
                - ```
                  ((Row_var 28)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 21) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 29)
                   (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 30)
                   (Solved
                    ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 21) (kind Output))))))
                  ```
                  
                - ```
                  ((Row_var 33)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 22) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 34)
                   (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 35)
                   (Solved
                    ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 22) (kind Output))))))
                  ```
                  
                - ```
                  ((Row_var 38)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                  ```
                  
                - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 40)
                   (Bounds (cur ()) (subr ((Row_var 5)))
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                  ```
                  
                - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 45)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 46)
                   (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                  ```
                  
                - ```
                  ((Row_var 47)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                  ```
                  
                - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
                - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 52)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                  ```
                  
                - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
                - ```
                  ((Row_var 54)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                  ```
                  
                - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
                - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
                - ```
                  ((Row_var 59)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                  ```
                  
                - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
                - ```
                  ((Row_var 61)
                   (Bounds (cur ()) (subr ((Row_var 7)))
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                  ```
                  
                - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
                - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
                - ```
                  ((Row_var 66)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 67)
                   (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                  ```
                  
                - ```
                  ((Row_var 68)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                  ```
                  
                - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
                - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 73)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                  ```
                  
                - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
                - ```
                  ((Row_var 75)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                  ```
                  
                - `((Row_var 77) (Bounds (cur ((Row_var 86))) (subr ((Row_var 70))) (lub ())))`
                - `((Row_var 79) (Bounds (cur ((Row_var 84))) (subr ((Row_var 72))) (lub ())))`
                - ```
                  ((Row_var 80)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 86))) (id ((sh_id 35) (kind Batch))))))
                  ```
                  
                - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
                - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
                - `((Row_var 84) (Bounds (cur ()) (subr ((Row_var 79))) (lub ())))`
                - `((Row_var 86) (Bounds (cur ()) (subr ((Row_var 77))) (lub ())))`
                </details>
              </details>
            </details>
          </details>
        - <details><summary>ineqs =</summary>
          
          - ```
            (Dim_eq (d1 (Var ((id 83) (label ()))))
             (d2 (Dim (d 16) (label ()) (proj_id ()))))
            ```
            
          - ```
            (Dim_ineq (cur (Var ((id 83) (label ()))))
             (subr (Dim (d 16) (label ()) (proj_id ()))))
            ```
            
          - ```
            (Dim_eq (d1 (Var ((id 85) (label ()))))
             (d2 (Dim (d 64) (label ()) (proj_id ()))))
            ```
            
          - ```
            (Dim_ineq (cur (Var ((id 85) (label ()))))
             (subr (Dim (d 64) (label ()) (proj_id ()))))
            ```
            
          </details>
        - <details><summary>env =</summary>
          
          - <details><summary><span style="font-family: monospace">dim_env</span></summary>
            
            - <details><summary></summary>
              
              - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
              - ```
                (((id 15) (label ()))
                 (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                  (lub ())))
                ```
                
              - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
              - ```
                (((id 21) (label ()))
                 (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                ```
                
              - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
              - ```
                (((id 27) (label ()))
                 (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                  (lub ())))
                ```
                
              - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
              - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
              - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
              - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
              - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
              </details>
            </details>
          - <details><summary><span style="font-family: monospace">row_env</span></summary>
            
            - <details><summary></summary>
              
              - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
              - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
              - ```
                ((Row_var 4)
                 (Solved
                  ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                ```
                
              - ```
                ((Row_var 5)
                 (Bounds (cur ((Row_var 40))) (subr ())
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                ```
                
              - ```
                ((Row_var 6)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                ```
                
              - ```
                ((Row_var 7)
                 (Bounds (cur ((Row_var 61))) (subr ())
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                ```
                
              - ```
                ((Row_var 8)
                 (Solved
                  ((dims ((Var ((id 83) (label ()))))) (bcast (Row_var (Row_var 84)))
                   (id ((sh_id 12) (kind Input))))))
                ```
                
              - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
              - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
              - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
              - ```
                ((Row_var 12)
                 (Solved
                  ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                   (id ((sh_id 17) (kind Output))))))
                ```
                
              - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
              - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
              - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
              - ```
                ((Row_var 18)
                 (Solved
                  ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                   (id ((sh_id 19) (kind Output))))))
                ```
                
              - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
              - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
              - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
              - ```
                ((Row_var 24)
                 (Solved
                  ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                   (id ((sh_id 20) (kind Output))))))
                ```
                
              - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
              - ```
                ((Row_var 28)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 21) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 29)
                 (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                ```
                
              - ```
                ((Row_var 30)
                 (Solved
                  ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 21) (kind Output))))))
                ```
                
              - ```
                ((Row_var 33)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 22) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 34)
                 (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                ```
                
              - ```
                ((Row_var 35)
                 (Solved
                  ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                   (id ((sh_id 22) (kind Output))))))
                ```
                
              - ```
                ((Row_var 38)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                ```
                
              - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
              - ```
                ((Row_var 40)
                 (Bounds (cur ()) (subr ((Row_var 5)))
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                ```
                
              - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
              - ```
                ((Row_var 45)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 46)
                 (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                ```
                
              - ```
                ((Row_var 47)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                ```
                
              - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
              - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
              - ```
                ((Row_var 52)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                ```
                
              - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
              - ```
                ((Row_var 54)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                ```
                
              - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
              - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
              - ```
                ((Row_var 59)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                ```
                
              - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
              - ```
                ((Row_var 61)
                 (Bounds (cur ()) (subr ((Row_var 7)))
                  (lub
                   (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                ```
                
              - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
              - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
              - ```
                ((Row_var 66)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                ```
                
              - ```
                ((Row_var 67)
                 (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                ```
                
              - ```
                ((Row_var 68)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                ```
                
              - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
              - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
              - ```
                ((Row_var 73)
                 (Solved
                  ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                ```
                
              - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
              - ```
                ((Row_var 75)
                 (Solved
                  ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                   (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                ```
                
              - `((Row_var 77) (Bounds (cur ((Row_var 86))) (subr ((Row_var 70))) (lub ())))`
              - `((Row_var 79) (Bounds (cur ((Row_var 84))) (subr ((Row_var 72))) (lub ())))`
              - ```
                ((Row_var 80)
                 (Solved
                  ((dims ((Var ((id 85) (label ()))))) (bcast (Row_var (Row_var 86)))
                   (id ((sh_id 35) (kind Batch))))))
                ```
                
              - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
              - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
              - `((Row_var 84) (Bounds (cur ()) (subr ((Row_var 79))) (lub ())))`
              - `((Row_var 86) (Bounds (cur ()) (subr ((Row_var 77))) (lub ())))`
              </details>
            </details>
          </details>
        - <details><summary>unify_dim =</summary>
          
          - ["lib/row.ml":234:29-277:100](./lib/row.ml#L234)
          - <details><summary><returns></summary>
            
            - `()`
            - <details><summary></summary>
              
              - <details><summary><span style="font-family: monospace">dim_env</span></summary>
                
                - <details><summary></summary>
                  
                  - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
                  - ```
                    (((id 15) (label ()))
                     (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                      (lub ())))
                    ```
                    
                  - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
                  - ```
                    (((id 21) (label ()))
                     (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                    ```
                    
                  - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
                  - ```
                    (((id 27) (label ()))
                     (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                      (lub ())))
                    ```
                    
                  - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                  - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                  - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
                  - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                  - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                  - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                  - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                  - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                  - `(((id 83) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                  </details>
                </details>
              - <details><summary><span style="font-family: monospace">row_env</span></summary>
                
                - <details><summary></summary>
                  
                  - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                  - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
                  - ```
                    ((Row_var 4)
                     (Solved
                      ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                    ```
                    
                  - ```
                    ((Row_var 5)
                     (Bounds (cur ((Row_var 40))) (subr ())
                      (lub
                       (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                         (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                    ```
                    
                  - ```
                    ((Row_var 6)
                     (Solved
                      ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                    ```
                    
                  - ```
                    ((Row_var 7)
                     (Bounds (cur ((Row_var 61))) (subr ())
                      (lub
                       (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                         (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                    ```
                    
                  - ```
                    ((Row_var 8)
                     (Solved
                      ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 84))) (id ((sh_id 12) (kind Input))))))
                    ```
                    
                  - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
                  - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
                  - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
                  - ```
                    ((Row_var 12)
                     (Solved
                      ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                       (id ((sh_id 17) (kind Output))))))
                    ```
                    
                  - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
                  - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
                  - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
                  - ```
                    ((Row_var 18)
                     (Solved
                      ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                       (id ((sh_id 19) (kind Output))))))
                    ```
                    
                  - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
                  - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
                  - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
                  - ```
                    ((Row_var 24)
                     (Solved
                      ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                       (id ((sh_id 20) (kind Output))))))
                    ```
                    
                  - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
                  - ```
                    ((Row_var 28)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                       (id ((sh_id 21) (kind Batch))))))
                    ```
                    
                  - ```
                    ((Row_var 29)
                     (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                    ```
                    
                  - ```
                    ((Row_var 30)
                     (Solved
                      ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                       (id ((sh_id 21) (kind Output))))))
                    ```
                    
                  - ```
                    ((Row_var 33)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                       (id ((sh_id 22) (kind Batch))))))
                    ```
                    
                  - ```
                    ((Row_var 34)
                     (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                    ```
                    
                  - ```
                    ((Row_var 35)
                     (Solved
                      ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                       (id ((sh_id 22) (kind Output))))))
                    ```
                    
                  - ```
                    ((Row_var 38)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                    ```
                    
                  - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                  - ```
                    ((Row_var 40)
                     (Bounds (cur ()) (subr ((Row_var 5)))
                      (lub
                       (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                         (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                    ```
                    
                  - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
                  - ```
                    ((Row_var 45)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                    ```
                    
                  - ```
                    ((Row_var 46)
                     (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                    ```
                    
                  - ```
                    ((Row_var 47)
                     (Solved
                      ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                    ```
                    
                  - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
                  - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
                  - ```
                    ((Row_var 52)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                    ```
                    
                  - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
                  - ```
                    ((Row_var 54)
                     (Solved
                      ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                    ```
                    
                  - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
                  - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
                  - ```
                    ((Row_var 59)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                    ```
                    
                  - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
                  - ```
                    ((Row_var 61)
                     (Bounds (cur ()) (subr ((Row_var 7)))
                      (lub
                       (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                         (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                    ```
                    
                  - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
                  - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
                  - ```
                    ((Row_var 66)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                    ```
                    
                  - ```
                    ((Row_var 67)
                     (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                    ```
                    
                  - ```
                    ((Row_var 68)
                     (Solved
                      ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                    ```
                    
                  - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
                  - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
                  - ```
                    ((Row_var 73)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                    ```
                    
                  - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
                  - ```
                    ((Row_var 75)
                     (Solved
                      ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                    ```
                    
                  - `((Row_var 77) (Bounds (cur ((Row_var 86))) (subr ((Row_var 70))) (lub ())))`
                  - `((Row_var 79) (Bounds (cur ((Row_var 84))) (subr ((Row_var 72))) (lub ())))`
                  - ```
                    ((Row_var 80)
                     (Solved
                      ((dims ((Var ((id 85) (label ()))))) (bcast (Row_var (Row_var 86)))
                       (id ((sh_id 35) (kind Batch))))))
                    ```
                    
                  - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
                  - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
                  - `((Row_var 84) (Bounds (cur ()) (subr ((Row_var 79))) (lub ())))`
                  - `((Row_var 86) (Bounds (cur ()) (subr ((Row_var 77))) (lub ())))`
                  </details>
                </details>
              </details>
            </details>
          - <details><summary>eq =</summary>
            
            - `(Var ((id 83) (label ())))`
            - `(Dim (d 16) (label ()) (proj_id ()))`
            </details>
          - <details><summary>env =</summary>
            
            - <details><summary><span style="font-family: monospace">dim_env</span></summary>
              
              - <details><summary></summary>
                
                - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
                - ```
                  (((id 15) (label ()))
                   (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                    (lub ())))
                  ```
                  
                - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
                - ```
                  (((id 21) (label ()))
                   (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                  ```
                  
                - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
                - ```
                  (((id 27) (label ()))
                   (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                    (lub ())))
                  ```
                  
                - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
                - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                </details>
              </details>
            - <details><summary><span style="font-family: monospace">row_env</span></summary>
              
              - <details><summary></summary>
                
                - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 4)
                   (Solved
                    ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 5)
                   (Bounds (cur ((Row_var 40))) (subr ())
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                  ```
                  
                - ```
                  ((Row_var 6)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 7)
                   (Bounds (cur ((Row_var 61))) (subr ())
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                  ```
                  
                - ```
                  ((Row_var 8)
                   (Solved
                    ((dims ((Var ((id 83) (label ()))))) (bcast (Row_var (Row_var 84)))
                     (id ((sh_id 12) (kind Input))))))
                  ```
                  
                - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
                - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
                - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 12)
                   (Solved
                    ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                     (id ((sh_id 17) (kind Output))))))
                  ```
                  
                - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
                - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
                - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
                - ```
                  ((Row_var 18)
                   (Solved
                    ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                     (id ((sh_id 19) (kind Output))))))
                  ```
                  
                - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
                - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
                - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
                - ```
                  ((Row_var 24)
                   (Solved
                    ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                     (id ((sh_id 20) (kind Output))))))
                  ```
                  
                - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
                - ```
                  ((Row_var 28)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 21) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 29)
                   (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 30)
                   (Solved
                    ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 21) (kind Output))))))
                  ```
                  
                - ```
                  ((Row_var 33)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 22) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 34)
                   (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 35)
                   (Solved
                    ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 22) (kind Output))))))
                  ```
                  
                - ```
                  ((Row_var 38)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                  ```
                  
                - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 40)
                   (Bounds (cur ()) (subr ((Row_var 5)))
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                  ```
                  
                - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 45)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 46)
                   (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                  ```
                  
                - ```
                  ((Row_var 47)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                  ```
                  
                - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
                - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 52)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                  ```
                  
                - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
                - ```
                  ((Row_var 54)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                  ```
                  
                - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
                - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
                - ```
                  ((Row_var 59)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                  ```
                  
                - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
                - ```
                  ((Row_var 61)
                   (Bounds (cur ()) (subr ((Row_var 7)))
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                  ```
                  
                - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
                - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
                - ```
                  ((Row_var 66)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 67)
                   (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                  ```
                  
                - ```
                  ((Row_var 68)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                  ```
                  
                - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
                - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 73)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                  ```
                  
                - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
                - ```
                  ((Row_var 75)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                  ```
                  
                - `((Row_var 77) (Bounds (cur ((Row_var 86))) (subr ((Row_var 70))) (lub ())))`
                - `((Row_var 79) (Bounds (cur ((Row_var 84))) (subr ((Row_var 72))) (lub ())))`
                - ```
                  ((Row_var 80)
                   (Solved
                    ((dims ((Var ((id 85) (label ()))))) (bcast (Row_var (Row_var 86)))
                     (id ((sh_id 35) (kind Batch))))))
                  ```
                  
                - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
                - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
                - `((Row_var 84) (Bounds (cur ()) (subr ((Row_var 79))) (lub ())))`
                - `((Row_var 86) (Bounds (cur ()) (subr ((Row_var 77))) (lub ())))`
                </details>
              </details>
            </details>
          - <details><summary><span style="font-family: monospace">dim1 = (Var ((id 83) (label ())))</span></summary>
            
            - ["lib/row.ml":235:6](./lib/row.ml#L235)
            </details>
          - <details><summary><span style="font-family: monospace">dim2 = (Dim (d 16) (label ()) (proj_id ()))</span></summary>
            
            - ["lib/row.ml":235:47](./lib/row.ml#L235)
            </details>
          </details>
        - <details><summary>solve_dim_ineq =</summary>
          
          - ["lib/row.ml":405:30-511:102](./lib/row.ml#L405)
          - <details><summary><returns></summary>
            
            - `()`
            - <details><summary></summary>
              
              - <details><summary><span style="font-family: monospace">dim_env</span></summary>
                
                - <details><summary></summary>
                  
                  - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
                  - ```
                    (((id 15) (label ()))
                     (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                      (lub ())))
                    ```
                    
                  - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
                  - ```
                    (((id 21) (label ()))
                     (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                    ```
                    
                  - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
                  - ```
                    (((id 27) (label ()))
                     (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                      (lub ())))
                    ```
                    
                  - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                  - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                  - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
                  - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                  - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                  - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                  - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                  - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                  - `(((id 83) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                  </details>
                </details>
              - <details><summary><span style="font-family: monospace">row_env</span></summary>
                
                - <details><summary></summary>
                  
                  - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                  - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
                  - ```
                    ((Row_var 4)
                     (Solved
                      ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                    ```
                    
                  - ```
                    ((Row_var 5)
                     (Bounds (cur ((Row_var 40))) (subr ())
                      (lub
                       (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                         (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                    ```
                    
                  - ```
                    ((Row_var 6)
                     (Solved
                      ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                    ```
                    
                  - ```
                    ((Row_var 7)
                     (Bounds (cur ((Row_var 61))) (subr ())
                      (lub
                       (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                         (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                    ```
                    
                  - ```
                    ((Row_var 8)
                     (Solved
                      ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 84))) (id ((sh_id 12) (kind Input))))))
                    ```
                    
                  - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
                  - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
                  - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
                  - ```
                    ((Row_var 12)
                     (Solved
                      ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                       (id ((sh_id 17) (kind Output))))))
                    ```
                    
                  - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
                  - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
                  - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
                  - ```
                    ((Row_var 18)
                     (Solved
                      ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                       (id ((sh_id 19) (kind Output))))))
                    ```
                    
                  - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
                  - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
                  - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
                  - ```
                    ((Row_var 24)
                     (Solved
                      ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                       (id ((sh_id 20) (kind Output))))))
                    ```
                    
                  - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
                  - ```
                    ((Row_var 28)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                       (id ((sh_id 21) (kind Batch))))))
                    ```
                    
                  - ```
                    ((Row_var 29)
                     (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                    ```
                    
                  - ```
                    ((Row_var 30)
                     (Solved
                      ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                       (id ((sh_id 21) (kind Output))))))
                    ```
                    
                  - ```
                    ((Row_var 33)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                       (id ((sh_id 22) (kind Batch))))))
                    ```
                    
                  - ```
                    ((Row_var 34)
                     (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                    ```
                    
                  - ```
                    ((Row_var 35)
                     (Solved
                      ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                       (id ((sh_id 22) (kind Output))))))
                    ```
                    
                  - ```
                    ((Row_var 38)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                    ```
                    
                  - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                  - ```
                    ((Row_var 40)
                     (Bounds (cur ()) (subr ((Row_var 5)))
                      (lub
                       (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                         (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                    ```
                    
                  - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
                  - ```
                    ((Row_var 45)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                    ```
                    
                  - ```
                    ((Row_var 46)
                     (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                    ```
                    
                  - ```
                    ((Row_var 47)
                     (Solved
                      ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                    ```
                    
                  - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
                  - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
                  - ```
                    ((Row_var 52)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                    ```
                    
                  - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
                  - ```
                    ((Row_var 54)
                     (Solved
                      ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                    ```
                    
                  - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
                  - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
                  - ```
                    ((Row_var 59)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                    ```
                    
                  - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
                  - ```
                    ((Row_var 61)
                     (Bounds (cur ()) (subr ((Row_var 7)))
                      (lub
                       (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                         (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                    ```
                    
                  - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
                  - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
                  - ```
                    ((Row_var 66)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                    ```
                    
                  - ```
                    ((Row_var 67)
                     (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                    ```
                    
                  - ```
                    ((Row_var 68)
                     (Solved
                      ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                    ```
                    
                  - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
                  - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
                  - ```
                    ((Row_var 73)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                    ```
                    
                  - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
                  - ```
                    ((Row_var 75)
                     (Solved
                      ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                    ```
                    
                  - `((Row_var 77) (Bounds (cur ((Row_var 86))) (subr ((Row_var 70))) (lub ())))`
                  - `((Row_var 79) (Bounds (cur ((Row_var 84))) (subr ((Row_var 72))) (lub ())))`
                  - ```
                    ((Row_var 80)
                     (Solved
                      ((dims ((Var ((id 85) (label ()))))) (bcast (Row_var (Row_var 86)))
                       (id ((sh_id 35) (kind Batch))))))
                    ```
                    
                  - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
                  - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
                  - `((Row_var 84) (Bounds (cur ()) (subr ((Row_var 79))) (lub ())))`
                  - `((Row_var 86) (Bounds (cur ()) (subr ((Row_var 77))) (lub ())))`
                  </details>
                </details>
              </details>
            </details>
          - `finish = false`
          - `cur = (Dim (d 16) (label ()) (proj_id ()))`
          - `subr = (Dim (d 16) (label ()) (proj_id ()))`
          - <details><summary>env =</summary>
            
            - <details><summary><span style="font-family: monospace">dim_env</span></summary>
              
              - <details><summary></summary>
                
                - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
                - ```
                  (((id 15) (label ()))
                   (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                    (lub ())))
                  ```
                  
                - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
                - ```
                  (((id 21) (label ()))
                   (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                  ```
                  
                - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
                - ```
                  (((id 27) (label ()))
                   (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                    (lub ())))
                  ```
                  
                - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
                - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 83) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                </details>
              </details>
            - <details><summary><span style="font-family: monospace">row_env</span></summary>
              
              - <details><summary></summary>
                
                - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 4)
                   (Solved
                    ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 5)
                   (Bounds (cur ((Row_var 40))) (subr ())
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                  ```
                  
                - ```
                  ((Row_var 6)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 7)
                   (Bounds (cur ((Row_var 61))) (subr ())
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                  ```
                  
                - ```
                  ((Row_var 8)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 84))) (id ((sh_id 12) (kind Input))))))
                  ```
                  
                - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
                - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
                - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 12)
                   (Solved
                    ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                     (id ((sh_id 17) (kind Output))))))
                  ```
                  
                - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
                - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
                - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
                - ```
                  ((Row_var 18)
                   (Solved
                    ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                     (id ((sh_id 19) (kind Output))))))
                  ```
                  
                - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
                - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
                - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
                - ```
                  ((Row_var 24)
                   (Solved
                    ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                     (id ((sh_id 20) (kind Output))))))
                  ```
                  
                - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
                - ```
                  ((Row_var 28)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 21) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 29)
                   (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 30)
                   (Solved
                    ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 21) (kind Output))))))
                  ```
                  
                - ```
                  ((Row_var 33)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 22) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 34)
                   (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 35)
                   (Solved
                    ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 22) (kind Output))))))
                  ```
                  
                - ```
                  ((Row_var 38)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                  ```
                  
                - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 40)
                   (Bounds (cur ()) (subr ((Row_var 5)))
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                  ```
                  
                - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 45)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 46)
                   (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                  ```
                  
                - ```
                  ((Row_var 47)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                  ```
                  
                - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
                - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 52)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                  ```
                  
                - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
                - ```
                  ((Row_var 54)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                  ```
                  
                - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
                - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
                - ```
                  ((Row_var 59)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                  ```
                  
                - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
                - ```
                  ((Row_var 61)
                   (Bounds (cur ()) (subr ((Row_var 7)))
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                  ```
                  
                - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
                - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
                - ```
                  ((Row_var 66)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 67)
                   (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                  ```
                  
                - ```
                  ((Row_var 68)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                  ```
                  
                - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
                - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 73)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                  ```
                  
                - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
                - ```
                  ((Row_var 75)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                  ```
                  
                - `((Row_var 77) (Bounds (cur ((Row_var 86))) (subr ((Row_var 70))) (lub ())))`
                - `((Row_var 79) (Bounds (cur ((Row_var 84))) (subr ((Row_var 72))) (lub ())))`
                - ```
                  ((Row_var 80)
                   (Solved
                    ((dims ((Var ((id 85) (label ()))))) (bcast (Row_var (Row_var 86)))
                     (id ((sh_id 35) (kind Batch))))))
                  ```
                  
                - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
                - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
                - `((Row_var 84) (Bounds (cur ()) (subr ((Row_var 79))) (lub ())))`
                - `((Row_var 86) (Bounds (cur ()) (subr ((Row_var 77))) (lub ())))`
                </details>
              </details>
            </details>
          - <details><summary><match -- branch 0></summary>
            
            - ["lib/row.ml":411:4](./lib/row.ml#L411)
            </details>
          </details>
        - <details><summary>unify_dim =</summary>
          
          - ["lib/row.ml":234:29-277:100](./lib/row.ml#L234)
          - <details><summary><returns></summary>
            
            - `()`
            - <details><summary></summary>
              
              - <details><summary><span style="font-family: monospace">dim_env</span></summary>
                
                - <details><summary></summary>
                  
                  - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
                  - ```
                    (((id 15) (label ()))
                     (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                      (lub ())))
                    ```
                    
                  - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
                  - ```
                    (((id 21) (label ()))
                     (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                    ```
                    
                  - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
                  - ```
                    (((id 27) (label ()))
                     (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                      (lub ())))
                    ```
                    
                  - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                  - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                  - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
                  - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                  - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                  - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                  - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                  - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                  - `(((id 83) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                  - `(((id 85) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  </details>
                </details>
              - <details><summary><span style="font-family: monospace">row_env</span></summary>
                
                - <details><summary></summary>
                  
                  - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                  - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
                  - ```
                    ((Row_var 4)
                     (Solved
                      ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                    ```
                    
                  - ```
                    ((Row_var 5)
                     (Bounds (cur ((Row_var 40))) (subr ())
                      (lub
                       (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                         (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                    ```
                    
                  - ```
                    ((Row_var 6)
                     (Solved
                      ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                    ```
                    
                  - ```
                    ((Row_var 7)
                     (Bounds (cur ((Row_var 61))) (subr ())
                      (lub
                       (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                         (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                    ```
                    
                  - ```
                    ((Row_var 8)
                     (Solved
                      ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 84))) (id ((sh_id 12) (kind Input))))))
                    ```
                    
                  - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
                  - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
                  - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
                  - ```
                    ((Row_var 12)
                     (Solved
                      ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                       (id ((sh_id 17) (kind Output))))))
                    ```
                    
                  - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
                  - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
                  - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
                  - ```
                    ((Row_var 18)
                     (Solved
                      ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                       (id ((sh_id 19) (kind Output))))))
                    ```
                    
                  - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
                  - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
                  - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
                  - ```
                    ((Row_var 24)
                     (Solved
                      ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                       (id ((sh_id 20) (kind Output))))))
                    ```
                    
                  - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
                  - ```
                    ((Row_var 28)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                       (id ((sh_id 21) (kind Batch))))))
                    ```
                    
                  - ```
                    ((Row_var 29)
                     (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                    ```
                    
                  - ```
                    ((Row_var 30)
                     (Solved
                      ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                       (id ((sh_id 21) (kind Output))))))
                    ```
                    
                  - ```
                    ((Row_var 33)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                       (id ((sh_id 22) (kind Batch))))))
                    ```
                    
                  - ```
                    ((Row_var 34)
                     (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                    ```
                    
                  - ```
                    ((Row_var 35)
                     (Solved
                      ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                       (id ((sh_id 22) (kind Output))))))
                    ```
                    
                  - ```
                    ((Row_var 38)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                    ```
                    
                  - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                  - ```
                    ((Row_var 40)
                     (Bounds (cur ()) (subr ((Row_var 5)))
                      (lub
                       (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                         (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                    ```
                    
                  - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
                  - ```
                    ((Row_var 45)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                    ```
                    
                  - ```
                    ((Row_var 46)
                     (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                    ```
                    
                  - ```
                    ((Row_var 47)
                     (Solved
                      ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                    ```
                    
                  - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
                  - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
                  - ```
                    ((Row_var 52)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                    ```
                    
                  - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
                  - ```
                    ((Row_var 54)
                     (Solved
                      ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                    ```
                    
                  - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
                  - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
                  - ```
                    ((Row_var 59)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                    ```
                    
                  - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
                  - ```
                    ((Row_var 61)
                     (Bounds (cur ()) (subr ((Row_var 7)))
                      (lub
                       (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                         (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                    ```
                    
                  - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
                  - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
                  - ```
                    ((Row_var 66)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                    ```
                    
                  - ```
                    ((Row_var 67)
                     (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                    ```
                    
                  - ```
                    ((Row_var 68)
                     (Solved
                      ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                    ```
                    
                  - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
                  - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
                  - ```
                    ((Row_var 73)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                    ```
                    
                  - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
                  - ```
                    ((Row_var 75)
                     (Solved
                      ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                    ```
                    
                  - `((Row_var 77) (Bounds (cur ((Row_var 86))) (subr ((Row_var 70))) (lub ())))`
                  - `((Row_var 79) (Bounds (cur ((Row_var 84))) (subr ((Row_var 72))) (lub ())))`
                  - ```
                    ((Row_var 80)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 86))) (id ((sh_id 35) (kind Batch))))))
                    ```
                    
                  - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
                  - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
                  - `((Row_var 84) (Bounds (cur ()) (subr ((Row_var 79))) (lub ())))`
                  - `((Row_var 86) (Bounds (cur ()) (subr ((Row_var 77))) (lub ())))`
                  </details>
                </details>
              </details>
            </details>
          - <details><summary>eq =</summary>
            
            - `(Var ((id 85) (label ())))`
            - `(Dim (d 64) (label ()) (proj_id ()))`
            </details>
          - <details><summary>env =</summary>
            
            - <details><summary><span style="font-family: monospace">dim_env</span></summary>
              
              - <details><summary></summary>
                
                - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
                - ```
                  (((id 15) (label ()))
                   (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                    (lub ())))
                  ```
                  
                - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
                - ```
                  (((id 21) (label ()))
                   (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                  ```
                  
                - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
                - ```
                  (((id 27) (label ()))
                   (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                    (lub ())))
                  ```
                  
                - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
                - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 83) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                </details>
              </details>
            - <details><summary><span style="font-family: monospace">row_env</span></summary>
              
              - <details><summary></summary>
                
                - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 4)
                   (Solved
                    ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 5)
                   (Bounds (cur ((Row_var 40))) (subr ())
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                  ```
                  
                - ```
                  ((Row_var 6)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 7)
                   (Bounds (cur ((Row_var 61))) (subr ())
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                  ```
                  
                - ```
                  ((Row_var 8)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 84))) (id ((sh_id 12) (kind Input))))))
                  ```
                  
                - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
                - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
                - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 12)
                   (Solved
                    ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                     (id ((sh_id 17) (kind Output))))))
                  ```
                  
                - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
                - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
                - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
                - ```
                  ((Row_var 18)
                   (Solved
                    ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                     (id ((sh_id 19) (kind Output))))))
                  ```
                  
                - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
                - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
                - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
                - ```
                  ((Row_var 24)
                   (Solved
                    ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                     (id ((sh_id 20) (kind Output))))))
                  ```
                  
                - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
                - ```
                  ((Row_var 28)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 21) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 29)
                   (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 30)
                   (Solved
                    ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 21) (kind Output))))))
                  ```
                  
                - ```
                  ((Row_var 33)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 22) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 34)
                   (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 35)
                   (Solved
                    ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 22) (kind Output))))))
                  ```
                  
                - ```
                  ((Row_var 38)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                  ```
                  
                - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 40)
                   (Bounds (cur ()) (subr ((Row_var 5)))
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                  ```
                  
                - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 45)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 46)
                   (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                  ```
                  
                - ```
                  ((Row_var 47)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                  ```
                  
                - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
                - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 52)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                  ```
                  
                - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
                - ```
                  ((Row_var 54)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                  ```
                  
                - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
                - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
                - ```
                  ((Row_var 59)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                  ```
                  
                - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
                - ```
                  ((Row_var 61)
                   (Bounds (cur ()) (subr ((Row_var 7)))
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                  ```
                  
                - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
                - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
                - ```
                  ((Row_var 66)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 67)
                   (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                  ```
                  
                - ```
                  ((Row_var 68)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                  ```
                  
                - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
                - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 73)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                  ```
                  
                - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
                - ```
                  ((Row_var 75)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                  ```
                  
                - `((Row_var 77) (Bounds (cur ((Row_var 86))) (subr ((Row_var 70))) (lub ())))`
                - `((Row_var 79) (Bounds (cur ((Row_var 84))) (subr ((Row_var 72))) (lub ())))`
                - ```
                  ((Row_var 80)
                   (Solved
                    ((dims ((Var ((id 85) (label ()))))) (bcast (Row_var (Row_var 86)))
                     (id ((sh_id 35) (kind Batch))))))
                  ```
                  
                - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
                - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
                - `((Row_var 84) (Bounds (cur ()) (subr ((Row_var 79))) (lub ())))`
                - `((Row_var 86) (Bounds (cur ()) (subr ((Row_var 77))) (lub ())))`
                </details>
              </details>
            </details>
          - <details><summary><span style="font-family: monospace">dim1 = (Var ((id 85) (label ())))</span></summary>
            
            - ["lib/row.ml":235:6](./lib/row.ml#L235)
            </details>
          - <details><summary><span style="font-family: monospace">dim2 = (Dim (d 64) (label ()) (proj_id ()))</span></summary>
            
            - ["lib/row.ml":235:47](./lib/row.ml#L235)
            </details>
          </details>
        - <details><summary>solve_dim_ineq =</summary>
          
          - ["lib/row.ml":405:30-511:102](./lib/row.ml#L405)
          - <details><summary><returns></summary>
            
            - `()`
            - <details><summary></summary>
              
              - <details><summary><span style="font-family: monospace">dim_env</span></summary>
                
                - <details><summary></summary>
                  
                  - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
                  - ```
                    (((id 15) (label ()))
                     (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                      (lub ())))
                    ```
                    
                  - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
                  - ```
                    (((id 21) (label ()))
                     (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                    ```
                    
                  - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
                  - ```
                    (((id 27) (label ()))
                     (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                      (lub ())))
                    ```
                    
                  - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                  - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                  - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
                  - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                  - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                  - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                  - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                  - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                  - `(((id 83) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                  - `(((id 85) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                  </details>
                </details>
              - <details><summary><span style="font-family: monospace">row_env</span></summary>
                
                - <details><summary></summary>
                  
                  - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                  - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
                  - ```
                    ((Row_var 4)
                     (Solved
                      ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                    ```
                    
                  - ```
                    ((Row_var 5)
                     (Bounds (cur ((Row_var 40))) (subr ())
                      (lub
                       (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                         (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                    ```
                    
                  - ```
                    ((Row_var 6)
                     (Solved
                      ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                    ```
                    
                  - ```
                    ((Row_var 7)
                     (Bounds (cur ((Row_var 61))) (subr ())
                      (lub
                       (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                         (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                    ```
                    
                  - ```
                    ((Row_var 8)
                     (Solved
                      ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 84))) (id ((sh_id 12) (kind Input))))))
                    ```
                    
                  - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
                  - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
                  - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
                  - ```
                    ((Row_var 12)
                     (Solved
                      ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                       (id ((sh_id 17) (kind Output))))))
                    ```
                    
                  - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
                  - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
                  - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
                  - ```
                    ((Row_var 18)
                     (Solved
                      ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                       (id ((sh_id 19) (kind Output))))))
                    ```
                    
                  - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
                  - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
                  - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
                  - ```
                    ((Row_var 24)
                     (Solved
                      ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                       (id ((sh_id 20) (kind Output))))))
                    ```
                    
                  - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
                  - ```
                    ((Row_var 28)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                       (id ((sh_id 21) (kind Batch))))))
                    ```
                    
                  - ```
                    ((Row_var 29)
                     (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                    ```
                    
                  - ```
                    ((Row_var 30)
                     (Solved
                      ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                       (id ((sh_id 21) (kind Output))))))
                    ```
                    
                  - ```
                    ((Row_var 33)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                       (id ((sh_id 22) (kind Batch))))))
                    ```
                    
                  - ```
                    ((Row_var 34)
                     (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                    ```
                    
                  - ```
                    ((Row_var 35)
                     (Solved
                      ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                       (id ((sh_id 22) (kind Output))))))
                    ```
                    
                  - ```
                    ((Row_var 38)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                    ```
                    
                  - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                  - ```
                    ((Row_var 40)
                     (Bounds (cur ()) (subr ((Row_var 5)))
                      (lub
                       (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                         (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                    ```
                    
                  - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
                  - ```
                    ((Row_var 45)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                    ```
                    
                  - ```
                    ((Row_var 46)
                     (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                    ```
                    
                  - ```
                    ((Row_var 47)
                     (Solved
                      ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                    ```
                    
                  - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
                  - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
                  - ```
                    ((Row_var 52)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                    ```
                    
                  - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
                  - ```
                    ((Row_var 54)
                     (Solved
                      ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                    ```
                    
                  - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
                  - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
                  - ```
                    ((Row_var 59)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                    ```
                    
                  - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
                  - ```
                    ((Row_var 61)
                     (Bounds (cur ()) (subr ((Row_var 7)))
                      (lub
                       (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                         (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                    ```
                    
                  - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
                  - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
                  - ```
                    ((Row_var 66)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                    ```
                    
                  - ```
                    ((Row_var 67)
                     (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                    ```
                    
                  - ```
                    ((Row_var 68)
                     (Solved
                      ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                    ```
                    
                  - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
                  - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
                  - ```
                    ((Row_var 73)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                    ```
                    
                  - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
                  - ```
                    ((Row_var 75)
                     (Solved
                      ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                    ```
                    
                  - `((Row_var 77) (Bounds (cur ((Row_var 86))) (subr ((Row_var 70))) (lub ())))`
                  - `((Row_var 79) (Bounds (cur ((Row_var 84))) (subr ((Row_var 72))) (lub ())))`
                  - ```
                    ((Row_var 80)
                     (Solved
                      ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 86))) (id ((sh_id 35) (kind Batch))))))
                    ```
                    
                  - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
                  - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
                  - `((Row_var 84) (Bounds (cur ()) (subr ((Row_var 79))) (lub ())))`
                  - `((Row_var 86) (Bounds (cur ()) (subr ((Row_var 77))) (lub ())))`
                  </details>
                </details>
              </details>
            </details>
          - `finish = false`
          - `cur = (Dim (d 64) (label ()) (proj_id ()))`
          - `subr = (Dim (d 64) (label ()) (proj_id ()))`
          - <details><summary>env =</summary>
            
            - <details><summary><span style="font-family: monospace">dim_env</span></summary>
              
              - <details><summary></summary>
                
                - `(((id 13) (label ())) (Solved (Var ((id 15) (label ())))))`
                - ```
                  (((id 15) (label ()))
                   (Bounds (cur (((id 21) (label ())) ((id 27) (label ())))) (subr ())
                    (lub ())))
                  ```
                  
                - `(((id 19) (label ())) (Solved (Var ((id 21) (label ())))))`
                - ```
                  (((id 21) (label ()))
                   (Bounds (cur (((id 27) (label ())))) (subr (((id 15) (label ())))) (lub ())))
                  ```
                  
                - `(((id 25) (label ())) (Solved (Var ((id 27) (label ())))))`
                - ```
                  (((id 27) (label ()))
                   (Bounds (cur ()) (subr (((id 15) (label ())) ((id 21) (label ()))))
                    (lub ())))
                  ```
                  
                - `(((id 31) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                - `(((id 32) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 36) (label ())) (Solved (Dim (d 10) (label ()) (proj_id ()))))`
                - `(((id 37) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 41) (label ())) (Solved (Dim (d 2) (label ()) (proj_id ()))))`
                - `(((id 43) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 48) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 50) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 55) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 57) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 62) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 64) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 69) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 71) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 76) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                - `(((id 78) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 83) (label ())) (Solved (Dim (d 16) (label ()) (proj_id ()))))`
                - `(((id 85) (label ())) (Solved (Dim (d 64) (label ()) (proj_id ()))))`
                </details>
              </details>
            - <details><summary><span style="font-family: monospace">row_env</span></summary>
              
              - <details><summary></summary>
                
                - `((Row_var 1) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                - `((Row_var 2) (Bounds (cur ((Row_var 67))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 4)
                   (Solved
                    ((dims ((Dim (d 2) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 42))) (id ((sh_id 8) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 5)
                   (Bounds (cur ((Row_var 40))) (subr ())
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                  ```
                  
                - ```
                  ((Row_var 6)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 63))) (id ((sh_id 10) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 7)
                   (Bounds (cur ((Row_var 61))) (subr ())
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                  ```
                  
                - ```
                  ((Row_var 8)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 84))) (id ((sh_id 12) (kind Input))))))
                  ```
                  
                - `((Row_var 9) (Bounds (cur ((Row_var 82))) (subr ()) (lub ())))`
                - `((Row_var 10) (Bounds (cur ((Row_var 16))) (subr ()) (lub ())))`
                - `((Row_var 11) (Bounds (cur ((Row_var 17))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 12)
                   (Solved
                    ((dims ((Var ((id 15) (label ()))))) (bcast (Row_var (Row_var 14)))
                     (id ((sh_id 17) (kind Output))))))
                  ```
                  
                - `((Row_var 14) (Bounds (cur ((Row_var 20))) (subr ()) (lub ())))`
                - `((Row_var 16) (Bounds (cur ((Row_var 22))) (subr ((Row_var 10))) (lub ())))`
                - `((Row_var 17) (Bounds (cur ((Row_var 23))) (subr ((Row_var 11))) (lub ())))`
                - ```
                  ((Row_var 18)
                   (Solved
                    ((dims ((Var ((id 21) (label ()))))) (bcast (Row_var (Row_var 20)))
                     (id ((sh_id 19) (kind Output))))))
                  ```
                  
                - `((Row_var 20) (Bounds (cur ((Row_var 26))) (subr ((Row_var 14))) (lub ())))`
                - `((Row_var 22) (Bounds (cur ()) (subr ((Row_var 16))) (lub ())))`
                - `((Row_var 23) (Bounds (cur ()) (subr ((Row_var 17))) (lub ())))`
                - ```
                  ((Row_var 24)
                   (Solved
                    ((dims ((Var ((id 27) (label ()))))) (bcast (Row_var (Row_var 26)))
                     (id ((sh_id 20) (kind Output))))))
                  ```
                  
                - `((Row_var 26) (Bounds (cur ()) (subr ((Row_var 20))) (lub ())))`
                - ```
                  ((Row_var 28)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 21) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 29)
                   (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 21) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 30)
                   (Solved
                    ((dims ((Dim (d 2) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 21) (kind Output))))))
                  ```
                  
                - ```
                  ((Row_var 33)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 22) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 34)
                   (Solved ((dims ()) (bcast Broadcastable) (id ((sh_id 22) (kind Input))))))
                  ```
                  
                - ```
                  ((Row_var 35)
                   (Solved
                    ((dims ((Dim (d 1) (label ()) (proj_id ())))) (bcast Broadcastable)
                     (id ((sh_id 22) (kind Output))))))
                  ```
                  
                - ```
                  ((Row_var 38)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 44))) (id ((sh_id 23) (kind Batch))))))
                  ```
                  
                - `((Row_var 39) (Bounds (cur ((Row_var 46))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 40)
                   (Bounds (cur ()) (subr ((Row_var 5)))
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))))
                  ```
                  
                - `((Row_var 44) (Bounds (cur ((Row_var 49))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 45)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 49))) (id ((sh_id 25) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 46)
                   (Bounds (cur ((Row_var 53))) (subr ((Row_var 1) (Row_var 39))) (lub ())))
                  ```
                  
                - ```
                  ((Row_var 47)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 51))) (id ((sh_id 25) (kind Output))))))
                  ```
                  
                - `((Row_var 49) (Bounds (cur ((Row_var 56))) (subr ((Row_var 44))) (lub ())))`
                - `((Row_var 51) (Bounds (cur ((Row_var 58))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 52)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 56))) (id ((sh_id 27) (kind Batch))))))
                  ```
                  
                - `((Row_var 53) (Bounds (cur ((Row_var 60))) (subr ((Row_var 46))) (lub ())))`
                - ```
                  ((Row_var 54)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 58))) (id ((sh_id 27) (kind Output))))))
                  ```
                  
                - `((Row_var 56) (Bounds (cur ((Row_var 65))) (subr ((Row_var 49))) (lub ())))`
                - `((Row_var 58) (Bounds (cur ((Row_var 63))) (subr ((Row_var 51))) (lub ())))`
                - ```
                  ((Row_var 59)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 65))) (id ((sh_id 29) (kind Batch))))))
                  ```
                  
                - `((Row_var 60) (Bounds (cur ((Row_var 67))) (subr ((Row_var 53))) (lub ())))`
                - ```
                  ((Row_var 61)
                   (Bounds (cur ()) (subr ((Row_var 7)))
                    (lub
                     (((dims ((Dim (d 16) (label ()) (proj_id ()))))
                       (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))))
                  ```
                  
                - `((Row_var 63) (Bounds (cur ()) (subr ((Row_var 58))) (lub ())))`
                - `((Row_var 65) (Bounds (cur ((Row_var 70))) (subr ((Row_var 56))) (lub ())))`
                - ```
                  ((Row_var 66)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 70))) (id ((sh_id 31) (kind Batch))))))
                  ```
                  
                - ```
                  ((Row_var 67)
                   (Bounds (cur ((Row_var 74))) (subr ((Row_var 2) (Row_var 60))) (lub ())))
                  ```
                  
                - ```
                  ((Row_var 68)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 72))) (id ((sh_id 31) (kind Output))))))
                  ```
                  
                - `((Row_var 70) (Bounds (cur ((Row_var 77))) (subr ((Row_var 65))) (lub ())))`
                - `((Row_var 72) (Bounds (cur ((Row_var 79))) (subr ()) (lub ())))`
                - ```
                  ((Row_var 73)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 77))) (id ((sh_id 33) (kind Batch))))))
                  ```
                  
                - `((Row_var 74) (Bounds (cur ((Row_var 81))) (subr ((Row_var 67))) (lub ())))`
                - ```
                  ((Row_var 75)
                   (Solved
                    ((dims ((Dim (d 16) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 79))) (id ((sh_id 33) (kind Output))))))
                  ```
                  
                - `((Row_var 77) (Bounds (cur ((Row_var 86))) (subr ((Row_var 70))) (lub ())))`
                - `((Row_var 79) (Bounds (cur ((Row_var 84))) (subr ((Row_var 72))) (lub ())))`
                - ```
                  ((Row_var 80)
                   (Solved
                    ((dims ((Dim (d 64) (label ()) (proj_id ()))))
                     (bcast (Row_var (Row_var 86))) (id ((sh_id 35) (kind Batch))))))
                  ```
                  
                - `((Row_var 81) (Bounds (cur ()) (subr ((Row_var 74))) (lub ())))`
                - `((Row_var 82) (Bounds (cur ()) (subr ((Row_var 9))) (lub ())))`
                - `((Row_var 84) (Bounds (cur ()) (subr ((Row_var 79))) (lub ())))`
                - `((Row_var 86) (Bounds (cur ()) (subr ((Row_var 77))) (lub ())))`
                </details>
              </details>
            </details>
          - <details><summary><match -- branch 0></summary>
            
            - ["lib/row.ml":411:4](./lib/row.ml#L411)
            </details>
          </details>
        </details>
      </details>
    </details>
  </details>
- <details><summary>_debug_remaining_constraints</summary>
  
  - ["lib/shape.ml":582:6](./lib/shape.ml#L582)
  </details>
</details>
