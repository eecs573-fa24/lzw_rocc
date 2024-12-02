// See LICENSE.Berkeley for license details.
// See LICENSE.SiFive for license details.

package freechips.rocketchip.tile

import chisel3._
import chisel3.util._
import chisel3.experimental.IntParam

import org.chipsalliance.cde.config._
import org.chipsalliance.diplomacy.lazymodule._

import freechips.rocketchip.rocket.{
  MStatus, HellaCacheIO, TLBPTWIO, CanHavePTW, CanHavePTWModule,
  SimpleHellaCacheIF, M_XRD, PTE, PRV, M_SZ
}
import freechips.rocketchip.tilelink.{
  TLNode, TLIdentityNode, TLClientNode, TLMasterParameters, TLMasterPortParameters
}
import freechips.rocketchip.util.InOrderArbiter

class CAMAccelerator(opcodes: OpcodeSet)
    (implicit p: Parameters) extends LazyRoCC(opcodes) {
  override lazy val module = new CAMModule(this)
}

class CAMModule(outer: CAMAccelerator)(implicit p: Parameters) extends LazyRoCCModuleImp(outer)
    with HasCoreParameters {
  val cmd = Queue(io.cmd)
  val funct = cmd.bits.inst.funct
  val code = cmd.bits.rs1
  val c = cmd.bits.rs2

  val doLookupW = funct === 0.U
  // val doLookupNW = funct === 1.U
  // val doWrite = funct === 2.U
  val doRst = funct === 1.U
  val busy = RegInit(false.B)

  // val memRespTag = io.mem.resp.bits.tag(log2Up(outer.n)-1,0)

  // datapath
  val response = Mux(doLookupW,code + c,code)
  val count = RegInit(0.U(3.W))
  val ecycles = RegInit(0.U(3.W))

  when (cmd.fire && (doLookupW || doRst)) {
    ecycles := 5.U
  }

  when (count =/= 0.U || cmd.fire) {
    count := count + 1.U
    busy:= true.B
  }

  when (count === ecycles) {
    count := 0.U
    busy:= false.B
    ecycles := 3.U
  }

  cmd.ready := !busy
    // command resolved if no stalls AND not issuing a load that will need a request

  // PROC RESPONSE INTERFACE
  io.resp.valid := cmd.valid && !busy
    // valid response if valid command, need a response, and no stalls
  io.resp.bits.rd := cmd.bits.inst.rd
    // Must respond with the appropriate tag or undefined behavior
  io.resp.bits.data := response
    // Semantics is to always send out prior accumulator register value

  io.busy := cmd.valid || busy
    // Be busy when have pending memory requests or committed possibility of pending requests
  io.interrupt := false.B

}

