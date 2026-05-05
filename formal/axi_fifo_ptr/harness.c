#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

#include "../../include/axi_dual_port_route_shape.h"

void set_inputs(void);

bool nondet_bool(void);
uint8_t nondet_uint8_t(void);

struct module_axi_fifo_ptr_formal_top
{
  uint8_t head;
  uint8_t tail;
  uint8_t count;
  bool push;
  bool pop;
  uint8_t next_head;
  uint8_t next_tail;
  uint8_t next_count;
};

extern struct module_axi_fifo_ptr_formal_top axi_fifo_ptr_formal_top;

int main(void)
{
  const uint8_t head = nondet_uint8_t();
  const uint8_t tail = nondet_uint8_t();
  const uint8_t count = nondet_uint8_t();
  const bool push = nondet_bool();
  const bool pop = nondet_bool();

  axi_fifo_ptr_formal_top.head = head;
  axi_fifo_ptr_formal_top.tail = tail;
  axi_fifo_ptr_formal_top.count = count;
  axi_fifo_ptr_formal_top.push = push;
  axi_fifo_ptr_formal_top.pop = pop;
  set_inputs();

  const AxiBridgeFifoPtrControl ref =
      axi_bridge_fifo_ptr_control(head, tail, count, push, pop, 4u);

  assert(axi_fifo_ptr_formal_top.next_head == ref.next_head);
  assert(axi_fifo_ptr_formal_top.next_tail == ref.next_tail);
  assert(axi_fifo_ptr_formal_top.next_count == ref.next_count);

  if (head < 4u && tail < 4u && count <= 4u) {
    if (push) {
      assert(axi_fifo_ptr_formal_top.next_tail ==
             axi_bridge_next_ptr(tail, 4u));
    } else {
      assert(axi_fifo_ptr_formal_top.next_tail == tail);
    }
    if (pop) {
      assert(axi_fifo_ptr_formal_top.next_head ==
             axi_bridge_next_ptr(head, 4u));
    } else {
      assert(axi_fifo_ptr_formal_top.next_head == head);
    }
    if (push && pop) {
      assert(axi_fifo_ptr_formal_top.next_count == count);
    }
    if (!push && !pop) {
      assert(axi_fifo_ptr_formal_top.next_count == count);
    }
    if (push && !pop && count < 4u) {
      assert(axi_fifo_ptr_formal_top.next_count == count + 1u);
    }
    if (!push && pop && count > 0u) {
      assert(axi_fifo_ptr_formal_top.next_count == count - 1u);
    }
  }
}
